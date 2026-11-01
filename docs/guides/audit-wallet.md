# Build a watch-only audit wallet

Goal: a node that monitors incoming deposits to a specific wallet, without holding the spend key. Used by exchanges, accounting teams, and compliance auditors.

## Why an audit key

BLSCT separates view and spend at the cryptographic level. The audit key is `view_secret (32 bytes) || master_spend_pubkey (48 bytes)` = 80 bytes = 160 hex chars. Anyone with it can:

-   Derive every sub-address ever used.
-   Scan the chain and see every incoming output addressed to any of those sub-addresses.
-   Recover amounts and memos on those outputs.

Nobody with the audit key can:

-   Spend anything.
-   Derive further secrets.

See [Concepts → Wallet formats](../concepts/wallet-formats.md#audit-keys).

## Setup

### 1. Get the audit key from the main wallet

On the wallet holding the spend key:

```ts
const audit = client.getKeyManager().getAuditKeyHex();
console.log(audit);   // 160-hex string
```

Transmit this to the monitor host over a secure channel. Treat it as *semi-sensitive* — a leak reveals your full transaction history but does not enable theft.

### 2. Create the audit wallet

```ts
import { NavioClient } from 'navio-sdk';

const client = new NavioClient({
    walletDbPath: '/var/lib/navio-audit/wallet.db',
    electrum: { host: 'localhost', port: 50005 },
    restoreFromAuditKey: 'abc...160-hex...',
    restoreFromHeight: 50000,             // block when main wallet first funded
    network: 'testnet',
});

await client.initialize();
await client.sync({
    onProgress: (h, tip) => console.log(`sync ${h}/${tip}`),
});
```

Initial sync can take minutes to hours depending on `restoreFromHeight` and chain size.

### 3. Monitor incoming deposits

```ts
await client.startBackgroundSync({
    pollInterval: 10_000,
    onNewTransaction: async (txHash, outputHash, amount) => {
        // a new output was detected against one of our sub-addresses
        const utxo = (await client.getAllOutputs()).find(o => o.outputHash === outputHash);
        if (!utxo) return;
        await creditDeposit({
            depositTxHash:    txHash,
            depositOutputHash: outputHash,
            amountSats:        amount,
            blockHeight:       utxo.blockHeight,
            memo:              utxo.memo,
        });
    },
    onError: (err) => console.error('sync err:', err),
});
```

### 4. `creditDeposit` pattern

```ts
async function creditDeposit(d: {
    depositTxHash: string;
    depositOutputHash: string;
    amountSats: bigint;
    blockHeight: number;
    memo: string | null;
}) {
    // idempotency — never credit the same outputHash twice
    const existing = await db.deposits.findUnique({ where: { outputHash: d.depositOutputHash } });
    if (existing) return;

    // confirmation policy
    const tip = (await client.getChainTip()).height;
    const confirmations = tip - d.blockHeight + 1;
    const status = confirmations >= 6 ? 'confirmed' : 'pending';

    await db.deposits.create({
        data: {
            outputHash: d.depositOutputHash,
            txHash:     d.depositTxHash,
            amountSats: d.amountSats.toString(),
            confirmations,
            memo:       d.memo,
            status,
            receivedAt: new Date(),
        },
    });
}
```

## Node-side audit wallet with `navio-cli`

The same watch-only wallet can live in `naviod` instead of the SDK.

```bash
# 1. on the wallet holding the spend key
navio-cli -rpcwallet=main getblsctauditkey          # 160-hex audit key

# 2. on the monitor node: a 160-hex seed is treated as an audit key,
#    and disable_private_keys is set automatically
navio-cli -named createwallet wallet_name="audit" seed="<160-hex audit key>"

# 3. scan history (an audit-key wallet has no birthday, so pass a start height)
navio-cli -rpcwallet=audit rescanblockchain 50000

# 4. watch deposits
navio-cli -rpcwallet=audit listtransactions "*" 100
navio-cli -rpcwallet=audit getblsctbalance
```

What to expect:

-   **Invalid keys are refused up front** (master, after v0.2.2): an audit key whose view-key half is zero or out of range, or whose spend-key half is not a valid point, fails with `Invalid audit key: the view key or the spend key is not a valid key` (`RPC_INVALID_PARAMETER`) and no wallet file is left behind. Earlier releases accepted such keys and then watched the wrong sub-addresses.
-   **The wallet is keyless.** It holds only the audit key. `getblsctseed` fails with `RPC_WALLET_BLANK` (-37), `dumpmnemonic` with `RPC_WALLET_ERROR` (-4), `signblsctrawtransaction` is refused, and `createwallet` refuses a `passphrase` because there are no private keys to encrypt.
-   **`disable_private_keys=true` without an audit key** creates a wallet that holds no keys at all (master). Earlier releases generated a random private seed for it, which still loads but warns "Private keys detected in wallet … with disabled private keys". On such a keyless wallet `getblsctauditkey` fails with `RPC_WALLET_BLANK` (-37).
-   **Exchange key handling.** Export the audit key from the spend wallet and import it here; do not pass the master seed or mnemonic together with `disable_private_keys=true`, which `createwallet` refuses on master.
-   `getblsctbalance`, `gettokenbalance` and `getnftbalance` include watch-only outputs by default on a watch-only wallet.

## Addresses the audit wallet can see

The audit key lets the monitor derive every sub-address *up to the current sub-address pool size*. If the main wallet generates address #1000 on `account=0`, the audit wallet must have a pool of ≥ 1000 to detect outputs to it.

Extend the pool ahead of time:

```ts
for (let i = 0; i < 2000; i++) {
    client.getKeyManager().generateNewSubAddress(0);
}
```

This costs nothing — deriving a sub-address is pure computation.

## Security posture

-   **Network isolation.** The monitor host needs outbound access to the Electrum/P2P backend only. No inbound unless you want remote queries (then TLS + auth).
-   **No spending.** The audit wallet cannot sign. If the spend key is on a cold signer, the monitor cannot withdraw even if fully compromised.
-   **Rotation.** If the audit key is suspected leaked, rotate by moving funds to a new wallet (new mnemonic). The old audit key still works on the old wallet's history.
-   **Backup.** The audit wallet DB is a derived artefact — you can rebuild from the audit key at any time. But keeping a recent backup shortens sync time after a disaster.

## Reconciliation

Compare the audit wallet's view to what the exchange expects:

```bash
curl localhost:3001/api/supply/block/$HEIGHT
# compare against SELECT SUM(amount) FROM deposits WHERE blockHeight <= $HEIGHT
```

Any divergence indicates missed deposits (sync gap) or credited deposits without on-chain backing (integrity bug). Investigate before unblocking withdrawals.
