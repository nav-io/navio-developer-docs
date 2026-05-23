# Run a staking node on a VPS

Goal: fresh Debian 12 VPS → running `naviod` + `navio-staker` with a stake-locked wallet. Hardened per the [security hardening](../node/security.md) baseline.

!!! warning "No systemd"
    Examples below use runit for supervision. Any non-systemd supervisor (OpenRC, s6, supervisord, Docker) works equivalently. Navio docs deliberately avoid systemd. If your distro defaults to systemd you can either install runit alongside it or switch to a non-systemd distro (Alpine, Artix, Devuan, Void, Chimera Linux, Gentoo).

## VPS sizing

Full hardware requirements (min vs recommended, rationale): [node/staking → Hardware requirements](../node/staking.md#hardware-requirements).

Quick picks for a VPS:

| Use case                        | vCPU | RAM   | Disk                      | Network         |
| ------------------------------- | ---- | ----- | ------------------------- | --------------- |
| Testnet, experiment             | 2    | 4 GB  | 40 GB NVMe, `prune=4096`  | 50 Mbps sym.    |
| Mainnet, long-running           | 8    | 8 GB  | 200 GB NVMe, unpruned     | 100 Mbps sym.   |
| Mainnet, pruned                 | 8    | 8 GB  | 80 GB NVMe, `prune=8192`  | 100 Mbps sym.   |

CPU must have AES-NI + AVX2 (x86-64) or ARMv8.2+ crypto extensions — Bulletproofs++ and BLS verify lean on both. **More cores scale**: Navio parallelises range-proof verify (one async task per proof) + view-tag detection + block script checks, so doubling cores meaningfully cuts IBD and per-block validation latency. Clock must be NTP-synced; > 30 s drift will cause stale PoPS templates.

## Initial hardening

```bash
# fresh boot
apt update && apt full-upgrade -y
apt install -y ufw fail2ban chrony runit

# SSH — key auth only
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
/etc/init.d/ssh reload 2>/dev/null || pkill -HUP sshd

# firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 33670/tcp comment 'Navio P2P'
ufw enable

# swap (optional, 2 GB)
fallocate -l 2G /swap && chmod 600 /swap && mkswap /swap && swapon /swap
echo '/swap none swap sw 0 0' >> /etc/fstab
```

## Install `naviod` + `navio-staker`

```bash
apt install -y build-essential cmake ninja-build pkg-config \
    libssl-dev libevent-dev bsdmainutils \
    libboost-system-dev libboost-filesystem-dev libboost-chrono-dev \
    libboost-test-dev libboost-thread-dev \
    libminiupnpc-dev libzmq3-dev libsqlite3-dev git

useradd -m -s /bin/bash navio
sudo -u navio git clone https://github.com/nav-io/navio-core.git /home/navio/navio-core
cd /home/navio/navio-core
sudo -u navio cmake -B build -G Ninja
sudo -u navio cmake --build build
cmake --install build
```

## Configuration + wallet

```bash
RPC_PW=$(openssl rand -base64 32)
sudo -u navio mkdir -p /home/navio/.navio
sudo -u navio tee /home/navio/.navio/navio.conf >/dev/null <<EOF
server=1
listen=1
testnet=1
rpcuser=navio
rpcpassword=$RPC_PW

[test]
addnode=testnet.nav.io
addnode=testnet2.nav.io
EOF

sudo -u navio /usr/local/bin/navio-wallet -blsct -chain=test -wallet=wallet create

echo "RPC password (store safely): $RPC_PW"
```

## Supervise with runit

`/etc/service/naviod/run`:

```sh
#!/bin/sh
exec chpst -u navio /usr/local/bin/naviod \
    -conf=/home/navio/.navio/navio.conf -printtoconsole 2>&1
```

`/etc/service/navio-staker/run`:

```sh
#!/bin/sh
exec chpst -u navio /usr/local/bin/navio-staker -testnet -wallet=wallet 2>&1
```

Make them executable and enable:

```bash
chmod +x /etc/service/naviod/run /etc/service/navio-staker/run
ln -s /etc/service/naviod /service/naviod
ln -s /etc/service/navio-staker /service/navio-staker

# status
sv status naviod navio-staker

# logs
sv status naviod        # tmux attach to /service/naviod/supervise, or tail the log dir if configured
```

Alternative: run each under `tmux` for ad-hoc operation (see [Install naviod](../node/install.md#tmux-example)).

## Encrypt the wallet

```bash
sudo -u navio navio-cli -testnet encryptwallet "long-random-passphrase"
# wallet restart triggered; restart naviod via your supervisor:
sv restart naviod
```

Unlock for staking-only:

```bash
sudo -u navio navio-cli -testnet walletpassphrase "long-random-passphrase" 99999999 true
#                                                                          ↑          ↑
#                                                                    timeout seconds  stakingOnly
```

`stakingOnly=true` keeps the wallet unlocked only for stake-signing; spends remain blocked until a full unlock.

Automation: do **not** store the passphrase on disk. Unlock manually after each reboot; reboots should be rare.

## Deposit + lock stake

Get testnet NAV from Discord `/faucet`. Then:

```bash
addr=$(sudo -u navio navio-cli -testnet getnewaddress)
echo "deposit to: $addr"

# wait for the deposit to confirm
sudo -u navio navio-cli -testnet getblsctbalance

# lock it (≥ 10,000 NAV per output)
sudo -u navio navio-cli -testnet stakelock 10000
```

No stake-age minimum — once confirmed and in the staked commitment set, the commitment is eligible.

## Verify staker is working

Navio does not ship a `getstakinginfo` RPC. Check that the staker is operating via:

-   The `navio-staker` stdout — supervisor-captured logs show each template poll and submission attempt.
-   Periodic reward transactions in `listblscttransactions`:

```bash
sudo -u navio navio-cli -testnet listblscttransactions "*" 50 0 true \
    | jq '[.[] | select(.category=="stake")] | length'
```

-   Chain-tip advancement at the expected ~60 s cadence.

## Monitoring

See [Node → Monitoring](../node/monitoring.md). Minimum alerting:

-   Peer count < 3 for > 5 min.
-   Block height not advancing for > 20 min (network-wide, not your share).
-   `navio-staker` process missing (supervisor alert).
-   Disk usage > 80 %.

## Upgrading

```bash
sv stop navio-staker
sv stop naviod

cd /home/navio/navio-core
sudo -u navio git fetch --tags
sudo -u navio git checkout $(git tag | tail -1)
sudo -u navio cmake -B build -G Ninja && sudo -u navio cmake --build build
cmake --install build

sv start naviod
# wait for sync
while ! sudo -u navio navio-cli -testnet getblockchaininfo >/dev/null 2>&1; do sleep 5; done
sv start navio-staker
```

Substitute `sv` with your supervisor's equivalent (`rc-service`, `docker compose`, …).

## Cold staking

Navio cold staking is **coming soon** — design not yet published. Until it ships, the spend key must live on the staker host. Mitigations:

-   Encrypt the wallet; only unlock with `stakingOnly=true` (above).
-   Minimise attack surface (firewall, non-root user, read-only filesystem).
-   Keep the bulk of funds off the staker node; lock only what you want to stake.

## Disaster recovery

1.  Rebuild VPS.
2.  Restore wallet from mnemonic.
3.  Re-lock stake after sync completes.

Expected downtime: 30–60 min on a freshly-built VPS.
