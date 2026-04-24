# Security hardening

Minimum production posture for a node that touches real funds.

## RPC authentication

Never ship `rpcuser=user, rpcpassword=password`. Two good options:

### Random password

Generate and rotate:

```bash
openssl rand -base64 32
# paste into navio.conf as rpcpassword=
```

### `rpcauth` hash

Store the hashed credential in `navio.conf` instead of the plaintext password. Generate with the helper script:

```bash
# from the navio-core source tree
./share/rpcauth/rpcauth.py alice
# outputs:
# String to be appended to navio.conf:
# rpcauth=alice:abc123...$def456...
# Your password: 3SRr...
```

Keep the plaintext password in your client's config only. The daemon never has it on disk.

## Bind RPC to loopback only

```ini
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
```

If remote RPC access is genuinely needed, front naviod with an authenticated reverse proxy (nginx + TLS + client cert, WireGuard, or SSH tunnel). **Do not** expose port 33677 to the public internet.

## Firewall

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 33670/tcp comment 'Navio P2P'
# DO NOT open 33677 unless you have a very specific reason
sudo ufw enable
```

## Run as non-root user

Create a dedicated `navio` user to run the daemon — never root:

```bash
sudo useradd -r -m -s /bin/bash navio
sudo install -o navio -g navio -d /home/navio/.navio
```

Run your supervisor with `User=navio` / `Group=navio` equivalents.

## Process isolation

Navio docs do not prescribe systemd. The same hardening intent translates across supervisors — apply whichever of the following your chosen init supports:

| Hardening intent                    | How to achieve it                                                                                              |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Drop privileges                     | runit `chpst -u navio`; OpenRC `command_user="navio"`; Docker `USER navio`; `setpriv` in wrapper scripts         |
| Read-only rootfs                    | Docker `read_only: true`; bubblewrap `--ro-bind /`; nsjail                                                     |
| `/tmp` isolation                    | Docker `tmpfs: /tmp`; bubblewrap `--tmpfs /tmp`; custom namespace                                              |
| Block `/home` access                | bubblewrap `--bind $DATADIR /home/navio/.navio --ro-bind / /`; Docker volume-only mount                          |
| Prevent new privileges              | `setpriv --no-new-privs` in wrapper; Docker `security_opt: [no-new-privileges:true]`                             |
| Restrict syscalls                   | seccomp-bpf profile via `prctl`; Docker `--security-opt seccomp=profile.json`                                   |
| Restrict network                    | Firewall rules (see below); network namespace; Docker network isolation                                         |
| File-descriptor limits              | `ulimit -n 65536`; Docker `ulimits:`; wrapper script                                                           |
| Mount noexec volumes                | `mount -o noexec`; Docker `volume` driver opts                                                                 |

Container-based deployments get most of this from Docker / Podman defaults. For bare-metal deployments that want a systemd-free equivalent, [bubblewrap](https://github.com/containers/bubblewrap) + runit is a solid combination.

## Tor (`.onion`) connectivity

```ini
proxy=127.0.0.1:9050
onion=127.0.0.1:9050
listen=1
externalip=<your-onion-address>
```

Run Tor on the same host, configure the hidden service for port 33670, copy the resulting onion address into `externalip=`. See [Bitcoin Core Tor guide](https://github.com/bitcoin/bitcoin/blob/master/doc/tor.md) — the pattern is identical.

## I2P / CJDNS

-   I2P: `i2psam=127.0.0.1:7656` (requires a local I2P router).
-   CJDNS: `cjdnsreachable=1` once CJDNS is active on the host.

## Disk / data protection

-   Full-disk encryption on the VPS. On Linux: LUKS2.
-   Enable wallet encryption (`encryptwallet <password>` or via SDK `keyManager.setPassword`).
-   Periodic encrypted wallet backups (see [Backup & restore](backup.md)). Store the encrypted blob off-host.

## OS baseline

-   Automatic security updates: `sudo apt-get install unattended-upgrades && sudo dpkg-reconfigure unattended-upgrades`.
-   SSH: key-auth only, `PermitRootLogin no`, `PasswordAuthentication no`.
-   Fail2ban on SSH and, optionally, on the RPC port if you must expose it.
-   Time sync: `chrony`, `openntpd`, or `ntpd` — whatever matches your distro. Clock drift causes handshake failures with peers.

## Separation of duties

Larger deployments separate:

-   **Cold signer** — holds the spending key, permanently offline or in HSM.
-   **Hot staker** — sees outputs through an audit key or restricted wallet, produces coinstake transactions.
-   **Ingest / exchange node** — audit-only, indexes deposits, triggers deposit crediting workflow.

The SDK's audit-key restore supports this pattern out of the box. See [Build a watch-only audit wallet](../guides/audit-wallet.md) and [Exchange integration](../guides/exchange-integration.md).

## Incident response

If you suspect compromise:

1.  Stop `naviod` and `navio-staker`.
2.  Move funds to a fresh wallet on a known-good device — **from the offline mnemonic, not the possibly-compromised wallet file**.
3.  Reinstall the host OS. Never try to "clean up" after a root compromise.
4.  Restore the wallet on the new host from mnemonic.
