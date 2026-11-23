# Changelog

!!! info "Auto-generated"
    This page aggregates release notes from every Navio repository. The nightly build pipeline fetches GitHub releases via `gh api` and renders them here. Links below point to the canonical release pages.

Until the pipeline runs, consult:

## navio-core

[Releases on GitHub](https://github.com/nav-io/navio-core/releases)

Notable items to watch for:

-   Consensus-breaking upgrades (announced with target activation heights).
-   BLSCT protocol version bumps.
-   RPC additions / deprecations.

Upcoming release:

-   **0.3.0** (in preparation from `master`, not yet tagged; the latest release is v0.2.2). Everything below is new in v0.3.0.

    -   **Removed RPCs and features.** All PSBT RPCs: node `analyzepsbt`, `combinepsbt`, `converttopsbt`, `createpsbt`, `decodepsbt`, `descriptorprocesspsbt`, `finalizepsbt`, `joinpsbts`, `utxoupdatepsbt` ([#529](https://github.com/nav-io/navio-core/pull/529)) and wallet `walletcreatefundedpsbt`, `walletprocesspsbt`, `psbtbumpfee` ([#549](https://github.com/nav-io/navio-core/pull/549)). `send`/`sendall` lost the `psbt` option and field; an incompletely signed result is returned in `hex` with `complete: false` ([#563](https://github.com/nav-io/navio-core/pull/563)). External signer support: `-signer`, `enumeratesigners`, `walletdisplayaddress`; `createwallet external_signer=true` is an error and such wallets no longer load ([#508](https://github.com/nav-io/navio-core/pull/508)). `-checkpoints` is accepted but has no effect ([#648](https://github.com/nav-io/navio-core/pull/648)). `migratewallet` ([#768](https://github.com/nav-io/navio-core/pull/768)). See [Removed RPCs](../rpc/index.md#removed-rpcs).
    -   **Transparent RPCs refused on BLSCT-only networks** (mainnet, testnet, `blsctregtest`, and signet now that it is a BLSCT network): `generatetoaddress`, `generatetodescriptor`, `generateblock`, `createrawtransaction`, `signrawtransactionwithkey`, `addmultisigaddress`, `newkeypool`, `settxfee` ([#578](https://github.com/nav-io/navio-core/pull/578)); `sendmany`, `send`, `sendall`, `fundrawtransaction`, `signrawtransactionwithwallet`, `bumpfee`, and `keypoolrefill` on non-BLSCT wallets ([#581](https://github.com/nav-io/navio-core/pull/581)). See [BLSCT-only networks](../rpc/index.md#blsct-only-networks).
    -   **`createwallet` and BLSCT wallets.** New BLSCT wallets have no legacy key manager (`keypoolsize` 0) ([#596](https://github.com/nav-io/navio-core/pull/596)); loading a seedless BLSCT wallet fails with an error instead of stopping the node ([#597](https://github.com/nav-io/navio-core/pull/597)); watch-only BLSCT wallets without an audit key hold no keys ([#598](https://github.com/nav-io/navio-core/pull/598)), and a watch-only wallet that holds a seed warns on load ([#629](https://github.com/nav-io/navio-core/pull/629)); invalid audit keys are refused before the wallet is created ([#628](https://github.com/nav-io/navio-core/pull/628)); `blank=true` with `seed`, `mnemonic` or `seedphrase_extension` is refused ([#630](https://github.com/nav-io/navio-core/pull/630)); `getblsctauditkey` on a keyless wallet returns `RPC_WALLET_BLANK` ([#627](https://github.com/nav-io/navio-core/pull/627)). BLSCT wallets always rescan without block filters ([#587](https://github.com/nav-io/navio-core/pull/587)).
    -   **Transaction history.** `gettransaction` reports BLSCT send `amount` and `fee` correctly ([#600](https://github.com/nav-io/navio-core/pull/600)); output-storage sends are no longer flagged `involvesWatchonly` ([#599](https://github.com/nav-io/navio-core/pull/599)); restored wallets show the correct amount for merged chains of sends ([#594](https://github.com/nav-io/navio-core/pull/594)); merged sends return to unconfirmed when their block is disconnected ([#619](https://github.com/nav-io/navio-core/pull/619)). The wallet records and trusts its own aggregated sends and swaps at broadcast ([#509](https://github.com/nav-io/navio-core/pull/509), [#588](https://github.com/nav-io/navio-core/pull/588)), and marks conflicted or expired output-storage sends so their coins come back ([#595](https://github.com/nav-io/navio-core/pull/595), [#589](https://github.com/nav-io/navio-core/pull/589)).
    -   **RPC changes.** The BLSCT sending, minting and staking RPCs document that `outputHash` is not a txid ([#626](https://github.com/nav-io/navio-core/pull/626)). NFT token ids `<hash>#<subid>` are accepted by `setswapintent`, `requestquote`, `sendquote`, `sendorder`, `broadcastorder` ([#582](https://github.com/nav-io/navio-core/pull/582)) and `createblsctrawtransaction` outputs ([#631](https://github.com/nav-io/navio-core/pull/631)). `cancelrfq` fails while a quote is being accepted. `listorders` gained `count`/`skip` and prunes expired orders ([#544](https://github.com/nav-io/navio-core/pull/544)). `generatetoaddress`/`generatetoblsctaddress` refuse a negative `maxtries`, and the generate RPCs document short returns ([#618](https://github.com/nav-io/navio-core/pull/618), [#632](https://github.com/nav-io/navio-core/pull/632)). `consolidate` returns the txids already sent when a later transaction fails. `fundrawtransaction` `input_weights` works, with a minimum weight of 149, and wallet input / `sendall` size estimates are fixed ([#571](https://github.com/nav-io/navio-core/pull/571)). `migratewallet` refuses before unloading ([#583](https://github.com/nav-io/navio-core/pull/583)); `dumpwallet` no longer stops the node with `-addresstype=bech32m` ([#580](https://github.com/nav-io/navio-core/pull/580)); `createmultisig` / `addmultisigaddress` refuse BLSCT address types and BLSCT wallets ([#579](https://github.com/nav-io/navio-core/pull/579)). `listdelegations` entries carry `commitment` ([#524](https://github.com/nav-io/navio-core/pull/524)).
    -   **Indexes and lookups.** New `-outindex` and `getoutputinfo`; `gettxfromoutputhash` uses the index when synced ([#481](https://github.com/nav-io/navio-core/pull/481)). `gettxoutsetinfo` hashes coins canonically; an existing `-coinstatsindex` is rebuilt on first start ([#485](https://github.com/nav-io/navio-core/pull/485)).
    -   **p2pmsg.** `getp2pmsginfo` `store` object with `entries`, `bytes`, `last_id` and `undecodable`; `clearp2pmsgs` counts undecodable messages it removes ([#574](https://github.com/nav-io/navio-core/pull/574)). `-p2pmsgstoresize` is split into per-scope budgets (inbox, session, broadcast). Each message kind is accepted only under its recipient key class ([#536](https://github.com/nav-io/navio-core/pull/536)).
    -   **P2P.** `-peeroutkeys` serves per-block BLSCT output keys to light wallets (`getoutkeys`/`outkeys`, `NODE_OUTKEYS`) ([#488](https://github.com/nav-io/navio-core/pull/488)); `NODE_P2P_WS` and `wsendpoint` advertise the WebSocket listener ([#496](https://github.com/nav-io/navio-core/pull/496)); `-whitelist` no longer applies to WebSocket peers ([#541](https://github.com/nav-io/navio-core/pull/541)); orphan parents are requested by output id ([#502](https://github.com/nav-io/navio-core/pull/502)). Bitcoin testnet and signet seeds were removed: connect testnet nodes with `-addnode`, `-seednode` or `-connect` (signet: also `-signetseednode`) ([#644](https://github.com/nav-io/navio-core/pull/644), [#647](https://github.com/nav-io/navio-core/pull/647)).
    -   **Staker.** Wallet-mode `navio-staker` pays its own delegated stakes to their reward address ([#524](https://github.com/nav-io/navio-core/pull/524)), and backs off failing delegation lookups and unreachable nodes ([#552](https://github.com/nav-io/navio-core/pull/552), [#560](https://github.com/nav-io/navio-core/pull/560)). It takes turns between the commitments it stakes, spreading delegated rewards ([#690](https://github.com/nav-io/navio-core/pull/690)), and checks its stats-file write before renaming it ([#635](https://github.com/nav-io/navio-core/pull/635)).
    -   **Chainstate.** Token/NFT predicates and staked commitments are replayed correctly after a crash mid-flush; affected nodes should restart once with `-reindex-chainstate` ([#553](https://github.com/nav-io/navio-core/pull/553)). Blocks whose coinbase carries a predicate that depends on another transaction in the block now disconnect correctly ([#554](https://github.com/nav-io/navio-core/pull/554)).
    -   **Tools and platforms.** `navio-wallet create` exits non-zero on failure ([#643](https://github.com/nav-io/navio-core/pull/643)) and validates `-seed` up front. Windows binaries use UTF-8 as the process code page ([#645](https://github.com/nav-io/navio-core/pull/645)). `-blsctfixedbase` is listed in `-help`. libblsct C API: `get_data_predicate_data` ([#523](https://github.com/nav-io/navio-core/pull/523)), stake delegation ([#522](https://github.com/nav-io/navio-core/pull/522)) and standalone `CTxOut` (de)serializers ([#543](https://github.com/nav-io/navio-core/pull/543)).
    -   **Header sync on proof-of-stake chains.** Headers presync accepts proof-of-stake retargets; a headers chain claiming work faster than 4× the node's recent rate is ignored (outside initial block download), and inbound peers cannot lead the node onto a fork more than 144 blocks deep ([#713](https://github.com/nav-io/navio-core/pull/713), [#759](https://github.com/nav-io/navio-core/pull/759)). See [Header sync](../concepts/p2p-protocol.md#header-sync-on-proof-of-stake-chains).
    -   **Mempool policy.** BLSCT transactions with a non-native fee output (`non-native-fee-output`) or no inputs (`blsct-vin-empty`) are non-standard ([#611](https://github.com/nav-io/navio-core/pull/611)); input scripts may make at most 16 + 2 per input `OP_BLSCHECKSIG` calls (`too-many-bls-signature-pairs`) ([#610](https://github.com/nav-io/navio-core/pull/610)). Block templates skip packages whose token predicates conflict, and mempool transactions whose predicates no longer hold after a block or reorg are evicted ([#609](https://github.com/nav-io/navio-core/pull/609)). Block validity is unchanged. See [Mempool policy](../concepts/p2p-protocol.md#mempool-policy).
    -   **Cover candidates.** Received candidates are verified against the chain and mempool before they are pooled, and `replycandidate` returns `hex` ([#612](https://github.com/nav-io/navio-core/pull/612)); served candidates spend only coins with 2 confirmations ([#755](https://github.com/nav-io/navio-core/pull/755)). p2pmsg envelopes are checked for oversized length fields before allocating ([#613](https://github.com/nav-io/navio-core/pull/613)).
    -   **Signet is a BLSCT network** with its own genesis, `snv` addresses, PoW to height 1000 then PoS, P2P port 48488 and signed blocks; `-signet` requires `-signetchallenge`; new `generatetoblsctaddress` `signetkey` argument and `navio-staker -signetblockkey` ([#731](https://github.com/nav-io/navio-core/pull/731)). See [Networks → Signet](../concepts/networks.md#signet).
    -   **Wallet RPC changes.** `migratewallet` removed ([#768](https://github.com/nav-io/navio-core/pull/768)). `createwallet` `mnemonic_passphrase` and `navio-wallet -mnemonicpassphrase` renamed to `seedphrase_extension` / `-seedphraseextension`, old names kept as deprecated aliases ([#663](https://github.com/nav-io/navio-core/pull/663)). `scantxoutset` and `scanblocks` refuse BLSCT addresses ([#756](https://github.com/nav-io/navio-core/pull/756)). `fee_may_include_other_senders` on sends whose fee may include other senders' fees ([#641](https://github.com/nav-io/navio-core/pull/641)); full-transaction wallets report their own fee for a merged block transaction ([#640](https://github.com/nav-io/navio-core/pull/640)); a swap taker's fee is reported as 0 ([#700](https://github.com/nav-io/navio-core/pull/700), [#702](https://github.com/nav-io/navio-core/pull/702)); `simulaterawtransaction` credits BLSCT outputs ([#636](https://github.com/nav-io/navio-core/pull/636)). Output-storage history rows held as bare outputs carry no `txid`, and `listunspent` lists each coin once ([#664](https://github.com/nav-io/navio-core/pull/664)) and applies `maximumCount` / `minimumSumAmount` after the address filter ([#712](https://github.com/nav-io/navio-core/pull/712), [#724](https://github.com/nav-io/navio-core/pull/724)).
    -   **Wallet behaviour.** Sends merged into a mempool transaction count as in the mempool ([#639](https://github.com/nav-io/navio-core/pull/639)); conflicted received payments are marked as such ([#650](https://github.com/nav-io/navio-core/pull/650)); `removeprunedfunds` fully forgets output-storage sends ([#651](https://github.com/nav-io/navio-core/pull/651)); mints spend native coins only ([#623](https://github.com/nav-io/navio-core/pull/623)); a failed `createwallet` or `restorewallet` removes what it created ([#674](https://github.com/nav-io/navio-core/pull/674), [#704](https://github.com/nav-io/navio-core/pull/704)); `acceptquotewallet`, `broadcastorder` and `replyquote` no longer hang on an exact-change swap half ([#660](https://github.com/nav-io/navio-core/pull/660)); `sendall` (transparent wallets) with an input the wallet does not hold fails cleanly instead of stopping the node ([#655](https://github.com/nav-io/navio-core/pull/655)).
    -   **libblsct C API.** `build_range_proof`, `sign_message` and `verify_msg_sig` take an explicit `msg_len` (**breaking**, [#714](https://github.com/nav-io/navio-core/pull/714)); `set_unsigned_transaction_emit_fee_output` / `get_unsigned_transaction_emit_fee_output` and unsigned-transaction format version 2 ([#677](https://github.com/nav-io/navio-core/pull/677)). See [libblsct C API changes](../blsct-lib/index.md#libblsct-c-api-changes-in-navio-core-v030).
    -   **Hardening and cleanup.** More secret material (scalars, mnemonic temporaries, hasher and parser state, MSM partial sums) is wiped after use; Bitcoin's BIP30 block exceptions, the multiprocess/IPC sources, the GUI interfaces and the Bitcoin Core verify, codesign and seed-crawling tools were removed; `navio-wallet` prints the error and exits non-zero when a tool command fails with an exception, instead of aborting ([#749](https://github.com/nav-io/navio-core/pull/749)).

Recent releases:

-   **0.2.2** (2026-09-27, latest)
    -   **User messaging** over p2pmsg: `sendp2pmsg`, `mintp2pmsgreplykey`, `subscribep2pmsgtopic`, `unsubscribep2pmsgtopic`, `listp2pmsgtopics`, `listp2pmsgs`, `clearp2pmsgs` ([#423](https://github.com/nav-io/navio-core/pull/423)). Envelope v2 with fuzzy-message-detection flags and `getp2pmsgdetectionkey` ([#474](https://github.com/nav-io/navio-core/pull/474)). `NODE_P2PMSG_LEAF` service bit for non-relaying bus clients ([#461](https://github.com/nav-io/navio-core/pull/461)).
    -   **WebSocket P2P listener** for browser clients, `-p2pwsbind` ([#462](https://github.com/nav-io/navio-core/pull/462)).
    -   **Recoverable output blinding keys** and the `signblsctoutput` RPC, which proves the wallet created an output ([#472](https://github.com/nav-io/navio-core/pull/472)).
    -   **Wallet-aware token RPCs** `listwallettokens` and `getwallettoken` (`ismine`) ([#440](https://github.com/nav-io/navio-core/pull/440)). `listorders` gained a `verbose` mode listing cached standing orders ([#413](https://github.com/nav-io/navio-core/pull/413)).
    -   **Aggregation**: type-aware cover selection and an input-derived cover target ([#429](https://github.com/nav-io/navio-core/pull/429), [#430](https://github.com/nav-io/navio-core/pull/430)); `consolidate` is aggregated with cover like plain sends ([#412](https://github.com/nav-io/navio-core/pull/412)); the swap fee is covered from spare coins ([#424](https://github.com/nav-io/navio-core/pull/424)).
    -   **Wallet fixes**: `consolidate` rejects a negative `max_inputs` ([#415](https://github.com/nav-io/navio-core/pull/415)); `listtransactions` pagination overflow ([#417](https://github.com/nav-io/navio-core/pull/417)); `createwallet` and `navio-wallet` require an ASCII `mnemonic_passphrase` for new wallets ([#418](https://github.com/nav-io/navio-core/pull/418), [#463](https://github.com/nav-io/navio-core/pull/463)).
    -   `scantxoutset` omits the per-output amount for BLSCT outputs ([#447](https://github.com/nav-io/navio-core/pull/447)). Validation rejects non-BLSCT transactions on BLSCT chains ([#480](https://github.com/nav-io/navio-core/pull/480)).
    -   libblsct C API: `build_tx_out` takes the memo length (breaking, [#444](https://github.com/nav-io/navio-core/pull/444)).
    -   Bitcoin Core backports for p2p/addrman, wallet, index/coinstats, log rate limiting and mutated-block rejection ([#449](https://github.com/nav-io/navio-core/pull/449), [#450](https://github.com/nav-io/navio-core/pull/450), [#451](https://github.com/nav-io/navio-core/pull/451), [#454](https://github.com/nav-io/navio-core/pull/454), [#455](https://github.com/nav-io/navio-core/pull/455)).
-   **0.2.1** (2026-09-10) — token balances in output-storage wallets ([#410](https://github.com/nav-io/navio-core/pull/410)); swap input gathering ([#411](https://github.com/nav-io/navio-core/pull/411)); malformed `script`/`scriptSig` hex rejected ([#416](https://github.com/nav-io/navio-core/pull/416)); served aggregation cover halves no longer reported as sends ([#435](https://github.com/nav-io/navio-core/pull/435)); `HKDF_Expand` output-iterator fix ([#397](https://github.com/nav-io/navio-core/pull/397)); C API mint builder and `build_range_proof` updates ([#431](https://github.com/nav-io/navio-core/pull/431), [#432](https://github.com/nav-io/navio-core/pull/432)).
-   **0.2.0** (2026-09-07) — consensus release; every node must upgrade.
    -   Consensus upgrade (PoPS v2 kernel); see the [release notes](https://github.com/nav-io/navio-core/releases/tag/v0.2.0).
    -   **blst backend**: herumi/mcl replaced by vendored supranational/blst across node, wallet and libblsct, byte-compatible on-chain ([#387](https://github.com/nav-io/navio-core/pull/387)). Deterministic batched G1 subgroup check ([#394](https://github.com/nav-io/navio-core/pull/394)); proof-verifier bounds ([#390](https://github.com/nav-io/navio-core/pull/390)).
    -   **P2P encrypted messaging** (`-p2pmsg`, `NODE_P2PMSG`) with identity/prekey separation and Dandelion++ stem routing ([#263](https://github.com/nav-io/navio-core/pull/263)); **aggregated sends** (`aggregatesend`, fee-0 cover candidates); **RFQ atomic swaps** (`setswapintent`, `requestquote`, `replyquote`, `acceptquotewallet`, `broadcastorder`). See [P2P encrypted messaging](../concepts/p2p-messaging.md).
    -   Miner defers transactions spending a staked commitment created earlier in the same template, and drops colliding staked-commitment outputs instead of stalling block production.
    -   ConnectBlock performance: reused staked-commitment set, memoised PoS body hash, parallel BLSCT output hashing ([#391](https://github.com/nav-io/navio-core/pull/391), [#392](https://github.com/nav-io/navio-core/pull/392)). Exhausted keypools return `RPC_WALLET_KEYPOOL_RAN_OUT` instead of stopping the node ([#395](https://github.com/nav-io/navio-core/pull/395)).
-   **0.1.9** (2026-08-29) — consensus change (set-membership padding index encoding); see the [release notes](https://github.com/nav-io/navio-core/releases/tag/v0.1.9). Fixed-base precompute for verification MSMs and other verify-path performance work.
-   **0.1.8** (2026-08-21) — priority staking fix: connecting a block evicts mempool transactions whose staked commitment it added, the miner drops duplicate staked commitments instead of building an invalid block, and `stakelock`/`delegatestake` fail when the commitment already exists ([#378](https://github.com/nav-io/navio-core/pull/378)). Navio birthday mnemonic (26 words) ([#340](https://github.com/nav-io/navio-core/pull/340)).
-   **0.1.7** (2026-08-08) — delegated cold staking ([#304](https://github.com/nav-io/navio-core/pull/304)); `deriveblsctonetimekey` ([#320](https://github.com/nav-io/navio-core/pull/320)); C API unsigned-output gamma and DATA predicate setter ([#318](https://github.com/nav-io/navio-core/pull/318)).
-   **0.1.6** (2026-07-28) — no crash when a BLSCT output arrives on a locked wallet ([#319](https://github.com/nav-io/navio-core/pull/319)).
-   **0.1.5** (2026-07-11) — `createwallet` and `navio-wallet` default to BLSCT ([#305](https://github.com/nav-io/navio-core/pull/305)); transparent-only spend and legacy key/backup RPCs guarded on BLSCT wallets ([#306](https://github.com/nav-io/navio-core/pull/306), [#313](https://github.com/nav-io/navio-core/pull/313)); `listblscttransactions` removed ([#311](https://github.com/nav-io/navio-core/pull/311)); PoW `getnetworkhashps` and mining difficulty fields removed ([#309](https://github.com/nav-io/navio-core/pull/309)); `listunspent` / `getreceivedby*` BLSCT-aware ([#307](https://github.com/nav-io/navio-core/pull/307)).
-   **0.1.4** (2026-07-08) — BIP-39 **mnemonic passphrase**, `createwallet mnemonic_passphrase` / `navio-wallet -mnemonicpassphrase` ([#315](https://github.com/nav-io/navio-core/pull/315)); `sendtoblsctaddress` honors `subtractfeefromamount` and stores `comment`/`comment_to` ([#302](https://github.com/nav-io/navio-core/pull/302)); regtest HRP `rnv` ([#316](https://github.com/nav-io/navio-core/pull/316)); mainnet `chainTxData` ([#303](https://github.com/nav-io/navio-core/pull/303)).
-   **0.1.3** — atomic-swap HTLC outputs auto-register as watch-only when built via `createblsctrawtransaction` ([#298](https://github.com/nav-io/navio-core/pull/298)).
-   **0.1.2** — robust BLSCT coin selection, consolidation, and spent-output tracking ([#296](https://github.com/nav-io/navio-core/pull/296)).
-   **0.1.1** — client-version bump; PoW→PoS mainnet bootstrap fix.
-   **0.1.0** — first stable release; activates **mainnet** (genesis 2026-07-01 13:00 UTC, genesis hash `0af3c23ae1ac4910693b7187ac61641d16d1cf49cba7acf8649d48e831d86b13`).

## navio-sdk

[Releases on GitHub](https://github.com/nav-io/navio-sdk/releases) · npm `navio-sdk`

-   **0.4.0** (2026-10-17) — [staking & cold staking](../sdk/staking.md): staked commitments tracked (`isStakedCommitment`, `getStakedOutputs`, `getStakedBalance`) and excluded from `getBalance` / `getUnspentOutputs` / coin selection; `delegateStake`, `getStakeDelegations`, `unstake`, `getMinStakeAmount`, `minStakeAmount` option. Sync reads outputs with long scripts correctly. `WalletDB` binds the token id in balance / output queries. Collection creation and minting check funding against the built transaction's fee. `DeepReorgError.reason` is `too-deep` at the retention limit. **Breaking for custom integrations:** new required `WalletOutput.isStakedCommitment`, new `IWalletDB.getOutputData`. Requires `@nav-io/navio-blsct` ^1.3.0.
-   **0.3.0** (2026-10-08) — `sync()` [recovers from reorgs by default](../sdk/sync.md#reorgs) (`stopOnReorg` now defaults to `false`; strict mode throws `ReorgError`); replaced blocks are re-scanned; bounded fork search with `MAX_REORG_DEPTH` and `DeepReorgError`; atomic revert via `IWalletDB.revertBlocksFrom`; Electrum paging resumes at `start + blocks.length`.
-   **0.2.2** (2026-09-22) — bounded sub-address recovery scan, so a spend can no longer hang the process (same contents as the 0.2.1 tag).
-   **0.2.0** (2026-09-21) — [recoverable output blinding keys](../sdk/sending.md#output-authorship): seed-derived blinding scalars, `recoverBlindingKey`, `signOutput`, `WalletOutput.ephemeralKey`; opt out with `deterministicBlindingKeys: false` / `randomBlindingKeys: true`.
-   **0.1.36** (2026-09-17) — the `p2p` backend syncs and transacts against a Navio full node end to end (correct magic / ports, broadcast, transaction lookup, header subscriptions, concurrent block download); exported P2P block parser.
-   **0.1.35** (2026-09-10) — standing-order tracking (`listStandingOrders`, `forgetStandingOrder`, `reserveInputs`).
-   **0.1.34** (2026-09-10) — `electrum.p2pmsgTimeout` (default 180 s) for RFQ / quote / order broadcasts; `expiry` validated as Unix seconds; `@nav-io/navio-blsct` ^1.2.0 (blst backend).
-   **0.1.33** (2026-09-09) — mint outputs use the same range-proof format as the rest of the transaction, chosen from the backend's tip; sub-addresses beyond the default pools are persisted and recovered; restoring a different seed into an existing database drops the previous wallet's data.

RFQ atomic-swap trading ([Token trading](../sdk/trading.md)) has been in released versions since 0.1.18.

## navio-p2pmsg

[Repository](https://github.com/nav-io/navio-p2pmsg) · npm `navio-p2pmsg` · [Docs](../sdk/p2pmsg.md)

-   **0.2.0** (2026-09-27) — envelope v2 with fuzzy message detection and archive retrieval (`syncArchive`); chat, groups, multi-device, backup and stream layers; BIP324 transport on by default. Wire-incompatible with 0.1.x; requires Navio Core v0.2.2+.
-   **0.1.0** (2026-09-17) — initial release: transports and peer pool, bus (BLS, ECIES, PoW, envelope), `MessagingClient`, stores.

## libblsct-bindings

[Repository](https://github.com/nav-io/libblsct-bindings) — no GitHub releases; versions are per package registry.

-   **TypeScript `@nav-io/navio-blsct` 1.3.0** (2026-10-16) — [stake-delegation API](../blsct-lib/transactions.md#stake-delegation) for cold staking (`UnsignedOutput.setStakeDelegation`, `parseStakeDelegationOwnerInfo`, …), `parseDataPredicateData`, `CTxOut.getScriptPubKeyHex()`, optional change address in `CTx.generate`. `CTxOut.getSpendingKey()` / `getBlindingKey()` now return `Point`.
-   **TypeScript 1.2.0** (2026-09-09) — built against navio-core's blst backend. **1.1.20** (2026-09-09) — `UnsignedOutput.mintToken` builds with the transaction's range-proof format.
-   **Python `navio-blsct` 0.0.41** (2026-11-04) — `set_unsigned_transaction_emit_fee_output` / `get_unsigned_transaction_emit_fee_output` for signing fee-0 cover candidates without a fee output (navio-core [#677](https://github.com/nav-io/navio-core/pull/677)); used by Navio Electrum 4.9.17. The repository's navio-core pin moved to that commit, which predates the C API's `msg_len` change in navio-core v0.3.0.
-   **Python `navio-blsct` 0.0.40** (2026-10-25) — stake-delegation output API, DATA predicate payload and full `scriptPubKey` readers, change address for `CTx`.
-   All bindings now build `libblsct` from one shared navio-core pin and can link a prebuilt library; C# builds natively on every OS and the Rust crate is tested on Linux, macOS and Windows (both from source).

The TypeScript package is scoped (`@nav-io/navio-blsct`); the unscoped `navio-blsct` on npm stopped at 1.1.15.

## navio-blocks

[Repository](https://github.com/nav-io/navio-blocks) — deployed from `main`, no tagged releases.

-   **2026-10-06** — Total Nodes no longer inflated by stale gossip mid-crawl; node counts use a 7-day window everywhere.
-   **2026-09-28** — [Navio service-bit badges](../explorer/peer-discovery.md#service-bits) per node (p2pmsg v1 / v2 / leaf / archive, BIP324, WebSocket); listening peers re-handshaken so badges reflect current services; total / listening / active node-count history (`/api/nodes/history`).
-   **2026-09-11** — new-outputs-over-time chart (`/api/outputs/timeline`).
-   **2026-09-08** — cold-staking tracking (`delegated` outputs, `/staking` page, `/api/staking/*`), p2pmsg overlay page (`/overlay`, `/api/p2pmsg/*`), grouped header navigation; time-series bucketing fixed.

## electrumx (Navio fork)

[Repository](https://github.com/nav-io/electrumx)

-   **2026-11-04** — [`blockchain.block.headers` priced like the other sync methods](../node/electrumx.md#header-sync-cost) (count/500 plus 10% of bandwidth), so new wallets can download all headers without being throttled; bandwidth discounts are applied after billing so they hold on fresh sessions.
-   **2026-10-27** — [`blockchain.transaction.get_outputs`](../node/electrumx.md#blockchaintransactionget_outputs) batch method (up to 250 output hashes, bandwidth billed at 10%).
-   **2026-09-26** — `get_range_txs_keys` returns every assembled block on a size-limited page, so `next_height` never skips blocks.

## navio-electrum

[Releases on GitHub](https://github.com/nav-io/navio-electrum/releases)

-   **4.9.17** (2026-11-05) — sends are aggregated with p2pmsg cover candidates pulled from navio-core relays (Electrum joins the bus as a leaf peer), and the unlocked wallet serves its own confirmed coins as fee-0 candidates; both on by default on mainnet. Requires Python `navio-blsct` 0.0.41.
-   **4.9.16** (2026-11-01) — the BIP-39 passphrase is called a seedphrase extension in Qt and the CLI.
-   **4.9.15** (2026-11-01) — air-gapped signing uses the range-proof version the watch-only wallet asks for.
-   **4.9.14** (2026-10-30) — air-gapped transactions can be saved and loaded as files.
-   **4.9.13** (2026-10-30) — wallets with long staking histories stay responsive on new blocks.
-   **4.9.12** (2026-10-30) — pasted delegate keys are cleaned up; intermittent delegation failure fixed.
-   **4.9.11** (2026-10-27) — batched output download (`get_outputs`) and resumable, visible catch-up sync; immature rewards shown separately from the unstaked balance.
-   **4.9.10** (2026-10-25) — unstaking a whole stake fixed; bundles Python `navio-blsct` 0.0.40 for cold-staking delegation; Android rebuilt with range-proof v2.
-   **4.9.9** (2026-09-08) — immature block rewards are not spent; staked vs unstaked balance shown; block rewards always get their own history entry.

## navio-docker

[Repository](https://github.com/nav-io/navio-docker)

-   **2026-10-10** — `tor` and `i2p` image variants (`<version>-tor` / `-i2p`) bundling a Tor client or the i2pd router; CI builds all variants as a parallel matrix. See [Self-host full stack](../guides/self-host-stack.md#images).

## navio-developer-docs

[Releases on GitHub](https://github.com/nav-io/navio-developer-docs/releases)

This site itself.

## Mainnet transition summary

Authoritative announcement: [Network Upgrade and Mainnet Transition Update (Medium)](https://medium.com/nav-coin/network-upgrade-and-mainnet-transition-update-40785628402d).

Key dates / heights:

-   **~10,500,000** (Navcoin height): mainnet activation, estimated end of June 2026.
-   **11,000,000** (Navcoin height): swap window closes.

Key parameters:

-   Initial supply: 81,743,678 NAV migrated.
-   Block reward: 8 NAV (`2 * COIN * (nPosTargetSpacing / 30)`, with a 120 s target spacing). Max block 4 MB.
-   BLSCT mandatory. PoPS consensus (both mainnet and testnet).
-   Community fund removed at genesis; unspent legacy balance burned.
-   Swap-window staking rewards burned.

## How to consume changes

Recommended operator workflow when a new release drops:

1.  Read the release notes.
2.  If consensus-breaking, upgrade **before** activation height.
3.  Dry-run on regtest.
4.  Schedule maintenance window for staking nodes (staking briefly offline during upgrade).
5.  Upgrade in staging first if running production services.
