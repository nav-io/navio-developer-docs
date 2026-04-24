# Utility RPC

| Command                        | Purpose                                                           |
| ------------------------------ | ----------------------------------------------------------------- |
| `validateaddress <address>`    | Check whether an address is well-formed, return details           |
| `estimatesmartfee <blocks>`    | Fee rate estimate targeting confirmation within `blocks`          |
| `estimaterawfee <blocks>`      | Low-level fee estimator output                                    |
| `createmultisig`               | Build an m-of-n multisig descriptor                                |
| `getdescriptorinfo`            | Inspect a wallet descriptor                                       |
| `deriveaddresses`              | Derive addresses from a descriptor                                 |
| `signmessagewithprivkey`       | Sign a message using a raw privkey (legacy, non-BLSCT)            |
| `verifymessage`                | Verify a signed message (legacy, non-BLSCT)                        |
| [`signblsmessage`](../blsct.md#signblsmessage) | **BLSCT-native** message signing                  |
| [`verifyblsmessage`](../blsct.md#verifyblsmessage) | **BLSCT-native** message verification         |
| `help [method]`                | List commands or show help for one                                |
| `uptime`                       | Seconds since `naviod` was started                                |
| `getrpcinfo`                   | Currently executing RPC calls                                     |
| `stop`                         | Shut down the daemon                                              |
