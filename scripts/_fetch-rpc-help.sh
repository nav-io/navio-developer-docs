#!/usr/bin/env bash
# Internal helper: boot regtest naviod, dump `help` per category, render markdown.
# Called by fetch-core-rpc.sh when `naviod` is available.
set -euo pipefail

CORE_DIR="${1:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/docs/rpc/categories"
DATADIR="$(mktemp -d)"

trap 'naviod -regtest -datadir="$DATADIR" stop 2>/dev/null || true; rm -rf "$DATADIR"' EXIT

echo "==> Starting naviod regtest"
naviod -regtest \
    -datadir="$DATADIR" \
    -daemon \
    -server=1 \
    -rpcuser=test \
    -rpcpassword=test \
    -rpcport=19999

# wait for RPC
for i in {1..30}; do
    if navio-cli -regtest -datadir="$DATADIR" -rpcport=19999 -rpcuser=test -rpcpassword=test getblockchaininfo >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

CLI="navio-cli -regtest -datadir=$DATADIR -rpcport=19999 -rpcuser=test -rpcpassword=test"

echo "==> Dumping help"
HELP_OUT="$DATADIR/help.txt"
$CLI help > "$HELP_OUT"

# For each category header (format: "== Categoryname ==") extract commands.
python3 - "$HELP_OUT" "$CLI" "$OUT" <<'PY'
import sys, re, subprocess, pathlib

help_path, cli_cmd, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
help_text = pathlib.Path(help_path).read_text()
cli = cli_cmd.split()

categories = {}
current = None
for line in help_text.splitlines():
    m = re.match(r'^== (\w[\w ]*?) ==\s*$', line.strip())
    if m:
        current = m.group(1).strip().lower()
        categories.setdefault(current, [])
        continue
    if current and line.strip():
        cmd = line.split()[0]
        if cmd and cmd[0].isalpha():
            categories[current].append(line.rstrip())

mapping = {
    'wallet': 'wallet.md',
    'blockchain': 'blockchain.md',
    'network': 'network.md',
    'rawtransactions': 'rawtransactions.md',
    'mining': 'mining.md',
    'mempool': 'mempool.md',
    'util': 'util.md',
    'generating': 'mining.md',
    'control': 'util.md',
    'hidden': None,
}

for cat, items in categories.items():
    fname = mapping.get(cat)
    if not fname:
        continue
    path = pathlib.Path(out_dir) / fname
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [f"# {cat.title()} RPC", "",
             "!!! info \"Auto-generated\"",
             "    Regenerated from `naviod -regtest help`.",
             "", "## Commands", ""]
    for spec in items:
        cmd = spec.split()[0]
        lines.append(f"### `{cmd}`\n")
        lines.append(f"`{spec.strip()}`\n")
        try:
            detail = subprocess.check_output(cli + ['help', cmd], stderr=subprocess.DEVNULL, text=True)
            desc = detail.strip().split('\n', 2)
            if len(desc) > 1:
                lines.append(desc[1].strip())
                lines.append('')
        except Exception:
            pass
        lines.append('---')
        lines.append('')
    path.write_text('\n'.join(lines))
    print(f"wrote {path}")
PY

echo "==> Done."
