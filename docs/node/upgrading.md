# Upgrading

## Between releases

Standard path for a minor/patch release:

```bash
# stop via your supervisor (examples; substitute for yours):
#   runit:   sv stop navio-staker naviod
#   OpenRC:  rc-service navio-staker stop; rc-service naviod stop
#   Docker:  docker compose stop navio-staker naviod
#   tmux:    tmux kill-session -t naviod; tmux kill-session -t staker

cd /home/navio/navio-core
sudo -u navio git fetch --tags
sudo -u navio git checkout <new-tag>
sudo -u navio ./autogen.sh && sudo -u navio ./configure && sudo -u navio make -j"$(nproc)"
sudo make install

# start naviod via your supervisor, wait for "loadblk thread exit" in debug.log,
# then start navio-staker:
#   runit:   sv start naviod; ...; sv start navio-staker
#   OpenRC:  rc-service naviod start; ...; rc-service navio-staker start
#   Docker:  docker compose start naviod; ...; docker compose start navio-staker
```

Check the release notes for any forced reindex (rare) or database format migration (announced in notes).

## Consensus upgrade

A consensus upgrade (hard fork) activates at a specific height. Operators **must** upgrade before activation or the node will fork off. Watch for release announcements tagged with "consensus" or "hardfork".

Pattern:

1.  **N weeks before activation** — announcement with target height.
2.  **Release published** — upgrade your node in a window before activation.
3.  **Activation block** — non-upgraded nodes fork off the network and follow a stale chain. Their balance numbers are not reliable.

Operational checklist:

-   Monitor `getblockchaininfo` for `softforks` status.
-   On activation block height + `6`, confirm `bestblockhash` matches other upgraded nodes and at least one block explorer.
-   If the node forked off (rare if you upgraded), `-reindex` after upgrading.

## Upgrading across testnet resets

When a testnet is cut and the datadir suffix changes:

1.  Stop `naviod`, `navio-staker`, and any wallet integrations.
2.  Move or delete the old testnet datadir, for example: `mv ~/.navio/testnet7 ~/.navio/testnet7.bak`.
3.  Update any hardcoded seed nodes in `navio.conf`.
4.  Start the new release.
5.  Resync. Old testnet wallets are not compatible — regenerate as needed for testing.

## Upgrading from Navcoin to Navio mainnet

At the mainnet transition (around Navcoin block height **10,500,000**, estimated end of June 2026):

1.  Navcoin users migrate NAV balances through the official swap process. The swap window closes at Navcoin block height **11,000,000**.
2.  The projected initial mainnet supply is **81,743,678 NAV** based on the migrated Navcoin total at the swap deadline.
3.  Navcoin community fund balances are **not migrated**.

Operationally: do not attempt to run a Navcoin node as a Navio mainnet node. They speak different wire protocols after the fork. Use a current `naviod` release and point it at the mainnet chain.

Authoritative source: [mainnet transition announcement](https://medium.com/nav-coin/network-upgrade-and-mainnet-transition-update-40785628402d).

## Database migrations

Some releases bump the chainstate or wallet DB version. Release notes call these out explicitly. Typical flow:

-   First start on new release migrates the DB in-place. Back up the datadir before first start.
-   If migration fails, restore the backup and file a bug report.

## Downgrading

Downgrading across a consensus upgrade is not supported — the older release cannot validate post-fork blocks. Downgrading within a minor series usually works but is not a supported path; release notes say so explicitly when it is.
