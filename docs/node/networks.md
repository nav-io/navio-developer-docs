# Running mainnet / testnet / signet / regtest

See [Concepts → Networks](../concepts/networks.md) for ports, magic bytes, and bech32 HRPs.

## Switching chain at runtime

```bash
naviod                 # mainnet (default)
naviod -testnet        # current testnet (testnet5)
naviod -signet         # signet
naviod -regtest        # local regtest
```

Chain selection drives:

-   Datadir subdirectory (`testnet5/`, `signet/`, `regtest/`).
-   Genesis block and checkpoints.
-   P2P port, RPC port, magic bytes.
-   Bech32 HRP (`nav` / `tnav` / `tnavrt`).
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
└── testnet5/            # if -testnet
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

## Regtest: instant blocks for development

Regtest starts with an empty chain you control. Mine blocks on demand:

```bash
naviod -regtest -daemon
addr=$(navio-cli -regtest getnewaddress)
navio-cli -regtest generatetoaddress 101 "$addr"   # note: PoW-style generation is a regtest-only path; mainnet/testnet are PoPS
navio-cli -regtest getblsctbalance
```

Regtest respects all consensus rules except difficulty — useful for testing BLSCT flows in isolation. See the [SDK quickstart](../sdk/quickstart.md) for integrating regtest into a dev loop.

## Current testnet directory name

Testnet versioning: the on-disk directory is `testnet5` on current releases. When a new testnet is cut, it bumps to `testnet6` etc. Scripts that hard-code the directory must be updated.

## When does a new testnet happen?

Typically after consensus-breaking protocol upgrades, or after persistent chain corruption during development. New testnet = new genesis, new seeds, new datadir name. Existing testnet wallets become incompatible and need to be regenerated.
