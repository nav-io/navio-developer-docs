# Running mainnet / testnet / signet / regtest / blsctregtest

See [Concepts → Networks](../concepts/networks.md) for ports, magic bytes, and bech32 HRPs.

## Switching chain at runtime

```bash
naviod                 # mainnet (default)
naviod -testnet        # current public testnet (testnet7)
naviod -signet         # signet
naviod -regtest        # local regtest
naviod -blsctregtest   # local BLSCT / PoPS regtest
```

Chain selection drives:

-   Datadir subdirectory (`testnet7/`, `signet/`, `regtest/`, `blsctregtest/`).
-   Genesis block and checkpoints.
-   P2P port, RPC port, magic bytes.
-   BLSCT address HRP on BLSCT-enabled chains (`nav` / `tnv` / `rnv`).
-   BLSCT chain context — affects address encoding, token-id padding, consensus rules.

## Datadir layout

```
~/.navio/
├── banlist.json
├── debug.log
├── mempool.dat
├── peers.dat
├── blocks/
│   ├── blk*.dat
│   ├── rev*.dat
│   └── index/
├── chainstate/
├── wallets/
│   └── wallet/
│       └── wallet.dat
├── testnet7/            # if -testnet
│   ├── debug.log
│   ├── blocks/
│   ├── chainstate/
│   └── wallets/
└── blsctregtest/        # if -blsctregtest
    ├── debug.log
    ├── blocks/
    ├── chainstate/
    └── wallets/
```

Each chain has an independent mempool, chainstate, and wallet directory — switching chains does not corrupt the other chain's data.

## Running multiple chains side by side

Two `naviod` instances with different datadirs:

```bash
naviod -datadir=/var/navio/main
naviod -datadir=/var/navio/test -testnet -port=33672 -rpcport=33679
```

Change `-port=` and `-rpcport=` to avoid collisions.

## Regtest modes for development

Plain `-regtest` is a non-BLSCT chain. For confidential-transaction and PoPS development, use `-blsctregtest` instead:

```bash
naviod -blsctregtest -daemon
addr=$(navio-cli -blsctregtest getnewaddress)
navio-cli -blsctregtest generatetoaddress 101 "$addr"
navio-cli -blsctregtest getblsctbalance
```

`-blsctregtest` keeps instant local mining but enables BLSCT and PoPS rules. Use plain `-regtest` when you specifically want the non-BLSCT rule set. The [SDK quickstart](../sdk/quickstart.md) still documents the SDK's current `regtest` network string; for chain-faithful core BLSCT testing, prefer `-blsctregtest`.

## Current testnet directory name

Testnet versioning: the on-disk directory is `testnet7` on the current branch. When a new testnet is cut, that suffix increments. Scripts that hard-code the directory must be updated.

## When does a new testnet happen?

Typically after consensus-breaking protocol upgrades, or after persistent chain corruption during development. New testnet = new genesis, new seeds, new datadir name. Existing testnet wallets become incompatible and need to be regenerated.
