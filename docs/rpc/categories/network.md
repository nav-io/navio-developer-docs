# Network RPC

!!! info "Auto-generated"
    Populated by the nightly pipeline from `naviod -help`.

## Peers

| Command                       | Purpose                                                 |
| ----------------------------- | ------------------------------------------------------- |
| `getpeerinfo`                 | Detailed info per connected peer                        |
| `getconnectioncount`          | Total peer count                                        |
| `addnode <ip> add/remove/onetry` | Manually add or connect to a peer                     |
| `disconnectnode`              | Drop a specific peer                                    |
| `listbanned`                  | Show banned IPs/CIDRs                                   |
| `setban <subnet> add/remove`  | Ban or unban an address                                 |
| `clearbanned`                 | Clear all bans                                          |

## Network state

| Command                       | Purpose                                                 |
| ----------------------------- | ------------------------------------------------------- |
| `getnetworkinfo`              | Protocol version, reachable networks, relay fee         |
| `getnettotals`                | Total bytes received/sent                               |
| `getaddrmaninfo`              | Address manager statistics                              |
| `getnodeaddresses`            | Known addresses from the address manager                |
| `ping`                        | Trigger ping to all peers                               |
