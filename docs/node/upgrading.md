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
sudo -u navio cmake -B build -G Ninja && sudo -u navio cmake --build build
sudo cmake --install build

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
-   If the node forked off, follow [Recovering from a version-mismatch fork](#recovering-from-a-version-mismatch-fork).

## Recovering from a version-mismatch fork

A node running an older consensus version than the rest of the network can reject a block the network accepts (or accept one it rejects) and then follow its own branch. Symptoms: `getblockcount` stops advancing or diverges from explorers, `bestblockhash` differs from other nodes at the same height, `getchaintips` lists the network's tip as `invalid` or `headers-only`, and stakers on the node keep producing blocks nobody else builds on.

1.  **Stop `navio-staker`** so it does not keep extending the wrong branch.
2.  **Upgrade `naviod`** to the current release. When building from source, use a fresh build directory so no stale objects from the old version are linked in, and confirm `naviod -version` before restarting.
3.  **Find the fork point.** Compare `getblockhash <h>` with a trusted explorer or an up-to-date node to find the first height where they differ.
4.  **Clear the invalid mark** the old binary left on the canonical branch: `navio-cli reconsiderblock <canonical block hash>` (the first canonical block after the fork point, or the canonical tip).
5.  **Make sure the node can fetch that branch.** If its peers are on the old branch too, connect to an up-to-date node: `navio-cli addnode <host> onetry` (on mainnet, `seed.nav.io` resolves to such peers).
6.  If it still prefers its own branch, `navio-cli invalidateblock <first block of the wrong branch>`; the node then reorganises onto the canonical chain. `-reindex` is the last resort.
7.  Confirm `bestblockhash` matches the network, then restart the staker.

Wallet transactions confirmed only on the abandoned branch become unconfirmed again after the reorg; coinbase rewards minted on it disappear.

## v0.2.x upgrade notes

-   **v0.2.0** was a mandatory consensus upgrade ("every node must update", per its release notes) and replaced the BLS backend (herumi/mcl → vendored supranational/blst; on-chain formats unchanged). Nodes on v0.1.x are not compatible with the current network.
-   **v0.2.2** switched the p2pmsg overlay to envelope v2 (`NODE_P2PMSG_V2`). v0.2.1-and-older nodes speak envelope v1 and the two overlays do not exchange messages, so aggregation cover candidates, RFQ quotes and user messages only reach peers on v0.2.2 or later.
-   **Next release** (changes merged on `master`):
    -   `-coinstatsindex` is wiped and rebuilt from genesis in the background on the first start, because coin hashing became canonical. A pruned node with `-coinstatsindex` must disable the index or `-reindex`. After a downgrade, delete `indexes/coinstats` (or `-reindex`) — and again after re-upgrading.
    -   If a node ever crashed or was killed while flushing the chainstate during token/NFT or staking activity, restart it once with `-reindex-chainstate` (pruned nodes: `-reindex`) to rebuild the token and staked-commitment sets.
    -   `-checkpoints` has no effect and logs a warning; remove it.
    -   Testnet and the default signet no longer ship seeds; add `addnode=` lines.
    -   `-whitelist` no longer applies to WebSocket (`-p2pwsbind`) peers.
    -   `-p2pmsgstoresize` is split into per-scope budgets; an inbox-only node that wants to keep as many messages as before needs a proportionally larger value.

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
