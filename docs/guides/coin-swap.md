# Coin Swap — Navcoin → Navio

The official one-way migration path from legacy Navcoin (`NAV`) to native Navio (`NAVIO`) runs at **[https://bridge.nav.io](https://bridge.nav.io)**.

The bridge uses an intermediate BEP-20 token, **wNAV** (Wrapped Navcoin), on BNB Smart Chain. Navcoin deposits mint wNAV; burning wNAV with a `nav1…` note triggers a native NAVIO payout on the Navio chain. The bridge is designed to be **auditable end-to-end** — every leg of the swap is publicly verifiable without trusting the operator.

- wNAV contract (BSC, chain 56): `0xbfef6ccfc830d3baca4f6766a0d4aaa242ca9f3d`
- Navcoin deposit address: `NKuyBkoGdZZSLyPbJEetheRhMjeznFZszf`
- Frontend source: [`nav-io/navio-bridge`](https://github.com/nav-io/navio-bridge)

---

## How to swap

### 1. Navcoin → wNAV (BSC)

1. Go to [bridge.nav.io](https://bridge.nav.io) → **Deposit**.
2. Connect a BSC wallet (MetaMask etc.). Switch to BNB Smart Chain.
3. Click **Register** once — a one-shot on-chain call that enrols your EVM address with the wNAV contract and unlocks a deposit address unique to you.
4. The UI shows your derived Navcoin deposit address (displayed as a QR + plain text). Send any amount of Navcoin to that address from your Navcoin wallet.
5. Once the Navcoin deposit confirms, the bridge mints the equivalent wNAV directly to your BSC wallet.

The derived deposit address is deterministic from your EVM address + chain id + token address + the bridge's xpub — you can re-derive it yourself offline.

### 2. wNAV → NAVIO (native)

1. On bridge.nav.io → **Withdraw**.
2. Provide a Navio recipient address. **It must be a bech32m address starting with `nav1…`** — that's the Navio mainnet HRP. Legacy Navcoin `N…` addresses and testnet `tnv1…` addresses are rejected.
3. The UI calls `burnWithNote(amount, "nav1…")` on the wNAV contract. The tokens are destroyed and the note carries the destination address.
4. After enough BSC confirmations for the bridge to consider the burn final, the bridge sends a native NAVIO transaction from its payout wallet to the bech32m address carried in the burn note.

End-to-end time is usually **a few minutes**. Allow up to **~15 minutes** under load or slow BSC confirmations before worrying.

---

## Audit — three independent checks

The bridge's reserves are public by construction. Nothing below requires cooperation from the operator.

### A. Navcoin supply deposited to the bridge

All inbound Navcoin sits in a single public address. Watch it on the Navcoin explorer:

> [https://explorer.navcoin.org/address/NKuyBkoGdZZSLyPbJEetheRhMjeznFZszf](https://explorer.navcoin.org/address/NKuyBkoGdZZSLyPbJEetheRhMjeznFZszf)

The current **balance** of that address = Navcoin held in custody against outstanding wNAV + NAVIO.

### B. wNAV burned on BSC

Every wNAV destined for Navio is burned via `burnWithNote(value, note)` which emits:

```solidity
event BurnedWithNote(address indexed a, uint256 v, string n);
```

Filter for burns **whose note starts with `nav1`** — those are the ones the bridge is obligated to pay out on Navio. Other notes (e.g. the `navio1` testnet placeholder, malformed notes, or notes pointing at unrelated chains) are not payout-bearing and should be reconciled separately.

Minimal standalone auditor (TypeScript, `viem`, no project deps beyond `npm install viem`):

```ts
import { createPublicClient, http, parseAbiItem, formatUnits } from 'viem';
import { bsc } from 'viem/chains';

const WNAV = '0xbfef6ccfc830d3baca4f6766a0d4aaa242ca9f3d' as const;
const DEPLOY_BLOCK = 8_300_000n;
const BURN_EVENT = parseAbiItem(
  'event BurnedWithNote(address indexed a, uint256 v, string n)',
);

const client = createPublicClient({
  chain: bsc,
  // Public BSC RPC. Swap in your own if you hit rate limits.
  transport: http('https://bsc-dataseed.binance.org'),
});

const RANGE = 3_000n; // safe chunk size for public BSC RPCs (they usually cap around 5000).
let total = 0n;
let count = 0;

const tip = await client.getBlockNumber();
for (let from = DEPLOY_BLOCK; from <= tip; from += RANGE + 1n) {
  const to = from + RANGE > tip ? tip : from + RANGE;
  const logs = await client.getLogs({
    address: WNAV,
    event: BURN_EVENT,
    fromBlock: from,
    toBlock: to,
  });
  for (const lg of logs) {
    const note = lg.args.n ?? '';
    // Only burns addressed to a Navio mainnet (nav1…) recipient are bridge-payout-bearing.
    if (!note.toLowerCase().startsWith('nav1')) continue;
    total += lg.args.v ?? 0n;
    count += 1;
    console.log(
      `${lg.blockNumber}  ${lg.transactionHash}  ${formatUnits(lg.args.v!, 8)} wNAV → ${note}`,
    );
  }
}

console.log(`\nTOTAL  ${count} burns  ${formatUnits(total, 8)} wNAV destined for Navio`);
```

wNAV has 8 decimals (same as NAV), so the value in the event is already directly comparable to NAV / NAVIO satoshis.

### C. NAVIO distributions from the bridge payout wallet

The bridge publishes a **BLSCT audit key** — 32-byte private view key + 48-byte public spending key (80 bytes total, hex-encoded). The audit key enables *read-only* sync of the bridge wallet: you see every outgoing distribution (amount, destination output, timestamp) without the spend authority.

**Published audit key** (placeholder — replace with the real value from the bridge page once issued):

```
auditKey = 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
```

#### Audit via `navio-cli` against a local `naviod`

```bash
# 1. Create a watch-only audit wallet.
navio-cli createwallet "bridge-audit" true false "" false true false
# createwallet args: name, disable_private_keys, blank, passphrase,
#                    avoid_reuse, descriptors, load_on_startup

# 2. Import the bridge audit key. rescan_from_height avoids scanning
#    pre-bridge history; set to the genesis-of-bridge height or 0.
navio-cli -rpcwallet=bridge-audit importblsctauditkey <auditKey> 0

# 3. Wait for the rescan to finish, then list outgoing transactions.
navio-cli -rpcwallet=bridge-audit listblscttransactions "*" 1000 0 true
```

`listblscttransactions` returns the wallet's entire visible history with the audit key. Filter for `category == "send"` to get bridge payouts; each entry carries `amount` (negative, in NAV), `confirmations`, `blockheight`, and the recipient stealth output.

#### Audit in-browser (same path the official page uses)

The bridge Audit page runs exactly this logic in the browser using `navio-sdk` + an Electrum backend. Source: [`navio-bridge/src/pages/Audit.tsx`](https://github.com/nav-io/navio-bridge/blob/master/src/pages/Audit.tsx) and [`navio-bridge/src/hooks/useNavioAudit.ts`](https://github.com/nav-io/navio-bridge/blob/master/src/hooks/useNavioAudit.ts). A minimal standalone version:

```ts
import { NavioClient } from 'navio-sdk';

const client = new NavioClient({
  network: 'mainnet',
  electrum: { host: 'electrum.nav.io', port: 50002, ssl: true },
  wallet: { dbName: 'bridge-audit-wallet' },
});

await client.init();
await client.restoreFromAuditKey(
  '00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
  /* restoreFromHeight */ 0,
);

await client.sync();

const txs = await client.listTransactions();
const outgoing = txs.filter((t) => t.direction === 'out');
const totalPaid = outgoing.reduce((acc, t) => acc + t.amount, 0n);
const balance = await client.getBalance();

console.log(`paid out: ${totalPaid}  balance on hand: ${balance}`);
```

### Reconciliation

The three quantities must satisfy:

```
navcoin_balance(NKuyBkoGdZZSLyPbJEetheRhMjeznFZszf)
    ≥ wnav_total_supply(0xbfef…9f3d)
    + sum(burns with note nav1…) − sum(navio_payouts)
```

Equivalently, **wNAV burned (destined for Navio) = NAVIO distributed + NAVIO on hand in bridge wallet**. The Audit page computes this live and surfaces a match/mismatch banner.

---

## Operational notes

- **Non-`nav1` burn notes** are skipped. If you burn with the wrong note format the wNAV is destroyed without payout and there is no automatic refund path. Always test with a small amount first.
