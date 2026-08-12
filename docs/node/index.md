# Node Operator

Everything you need to run and operate `naviod` in production.

| Page                                                | What's covered                                                                                                       |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| [Install naviod](install.md)                        | Build from source, Docker, release binaries. Supervisor-agnostic (runit / OpenRC / Docker / tmux) — no systemd assumed. |
| [navio.conf reference](configuration.md)            | Every config flag, grouped by category. RPC, network, wallet, BLSCT, logging.                                        |
| [Running mainnet / testnet](networks.md)            | Switching networks, datadir layout, chain-specific behaviour.                                                        |
| [Staking](staking.md)                               | `navio-staker`, `stakelock`/`stakeunlock`, minimum stake, expected rewards, private stake under PoPS.                |
| [Cold staking](cold-staking.md)                     | The most secure way to stake: staking key hot, spend key cold. Self-operated or delegated to an operator. `delegatestake`, operator mode, fees. |
| [ElectrumX server](electrumx.md)                    | Running an Electrum-compatible server for BLSCT-aware Electrum clients.                                              |
| [Pruning & reindex](pruning.md)                     | Block pruning, txindex, `-reindex`, `-reindex-chainstate`.                                                          |
| [Backup & restore](backup.md)                       | Wallet file backup, seed/mnemonic backup, audit-key export, encrypted snapshots.                                     |
| [Upgrading](upgrading.md)                           | Between releases, between networks, between consensus versions.                                                      |
| [Security hardening](security.md)                   | Firewall, Tor, non-root, process isolation via container / bubblewrap / runit, RPC auth.                              |
| [Monitoring](monitoring.md)                         | ZMQ publishers, RPC healthchecks, Prometheus via exporters, log rotation.                                            |
