# Mempool RPC

| Command                  | Purpose                                                         |
| ------------------------ | --------------------------------------------------------------- |
| `getmempoolinfo`         | Size, bytes, usage, min fee, mempool min fee                    |
| `getrawmempool`          | Array of txids currently in mempool                             |
| `getmempoolentry <txid>` | Entry details — fee, ancestors, descendants                      |
| `getmempoolancestors`    | Ancestors of a given tx                                         |
| `getmempooldescendants`  | Descendants of a given tx                                       |
| `testmempoolaccept`      | Dry-run acceptance of a raw tx                                  |
| `savemempool`            | Persist mempool to disk (useful before restarting)              |
