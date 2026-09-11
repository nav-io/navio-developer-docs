# P2P messaging commands

The JSON-RPC surface of the encrypted p2p messaging subsystem (`-p2pmsg`, default on) and the applications shipping on it: cover-candidate aggregation for private sends, and RFQ atomic swaps (standing orders, quotes, wallet-side settlement).

This page is **automatically generated** by `scripts/extract-blsct-rpc.py --p2pmsg` from [navio-core](https://github.com/nav-io/navio-core) source:

-   `src/rpc/p2pmsg.cpp`
-   `src/blsct/wallet/rpc.cpp` (p2pmsg-related wallet commands)

Run `navio-cli help <command>` on your node for the definitive help text — source may have evolved since the last documentation build.

See the [p2p encrypted messaging concept page](../concepts/p2p-messaging.md) for how the bus works (kind-blind relay, per-message PoW, identity/prekey split, Dandelion stem), and [Trade tokens with RFQ](../guides/rfq-trading.md) for the full maker/taker trading sequence in plain terms.

## Quick index

| Category | Commands |
| -------- | -------- |
| **Node state** | `getp2pmsginfo`, `rotatep2pmsginbox`, `sendp2pping` |
| **Aggregation (cover traffic)** | `aggregatesend`, `getaggregationhint`, `getp2pmsgaggregate`, `listpendingcandidaterequests`, `replycandidate`, `sendcandidate`, `addaggregationcandidate` |
| **RFQ swaps — taker** | `requestquote`, `listquotes`, `acceptquote`, `acceptquotewallet`, `listrfqs`, `cancelrfq` |
| **RFQ swaps — maker** | `setswapintent`, `clearswapintent`, `listswapintents`, `listpendingquoterequests`, `sendquote`, `replyquote`, `addrfqquote` |
| **Standing orders** | `sendorder`, `listorders` |

---

