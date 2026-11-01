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
| **Node state** | `getp2pmsginfo`, `rotatep2pmsginbox`, `getp2pmsgdetectionkey`, `sendp2pping` |
| **User messaging** | `sendp2pmsg`, `mintp2pmsgreplykey`, `subscribep2pmsgtopic`, `unsubscribep2pmsgtopic`, `listp2pmsgtopics`, `listp2pmsgs`, `clearp2pmsgs` |
| **Aggregation (cover traffic)** | `aggregatesend`, `getaggregationhint`, `getp2pmsgaggregate`, `listpendingcandidaterequests`, `replycandidate`, `sendcandidate`, `addaggregationcandidate` |
| **RFQ swaps — taker** | `requestquote`, `listquotes`, `acceptquote`, `acceptquotewallet`, `listrfqs`, `cancelrfq` |
| **RFQ swaps — maker** | `setswapintent`, `clearswapintent`, `listswapintents`, `listpendingquoterequests`, `sendquote`, `replyquote`, `addrfqquote` |
| **Standing orders** | `broadcastorder`, `sendorder`, `listorders` |

!!! note "Token arguments and NFTs"
    Every token argument of `setswapintent`, `requestquote`, `sendquote`, `sendorder` and `broadcastorder` takes the 64-hex token id, the token id followed by `#<subid>` for an NFT (the form `listorders` prints), or the empty string for NAV. The subid is plain decimal (no sign, leading zeros or `0x`). A malformed value fails with `RPC_INVALID_PARAMETER` and a message naming the argument, e.g. `buy_token must be a 64-hex token id, followed by #<subid> for an NFT, or empty for NAV`. `listswapintents` and `listpendingquoterequests` print the `#<subid>` suffix for NFTs.

!!! note "Message store cursors"
    When the user-message store is enabled (`-p2pmsgstoresize` above 0), `getp2pmsginfo` returns a `store` object with `entries`, `bytes`, `last_id` and `undecodable`. `undecodable` counts messages on disk that this node cannot read; they are not returned by `listp2pmsgs` and not counted in `entries` or `bytes`. `clearp2pmsgs` returns the number of messages it removed, including undecodable ones in its range, so it can be larger than what `listp2pmsgs` showed. To drop only what you have read, pass the highest id `listp2pmsgs` returned. `0`, the default, drops everything.

---

