#!/usr/bin/env python3
"""
Extract BLSCT RPC commands from navio-core source and render as Markdown.

Usage:
    python3 scripts/extract-blsct-rpc.py <path-to-navio-core> > docs/rpc/blsct.md

Parses each ``RPCHelpMan{...}`` entry in:
    - src/blsct/wallet/rpc.cpp
    - src/blsct/tokens/rpc.cpp
    - src/blsct/range_proof/rpc.cpp
    - src/wallet/rpc/backup.cpp (filtered to BLSCT-related commands)

and renders:
    - command name as ### heading
    - description
    - parameter table (name, type, required, default, description)
    - CLI / JSON-RPC examples

Intended to run in CI so the rendered RPC reference stays in sync with source.
"""
import re
import sys
import pathlib

FILES = [
    "src/blsct/wallet/rpc.cpp",
    "src/blsct/tokens/rpc.cpp",
    "src/blsct/range_proof/rpc.cpp",
    "src/wallet/rpc/backup.cpp",
]
BLSCT_KEYWORDS = ("blsct", "token", "nft", "stake", "mnemonic", "blsmessage")
EXPLICIT = {"getblsctseed", "getblsctauditkey", "dumpmnemonic", "importblsctscript"}


def find_matching(text, start, open_ch="{", close_ch="}"):
    depth = 0
    i = start
    while i < len(text):
        c = text[i]
        if c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return i
        elif c == '"':
            i += 1
            while i < len(text) and text[i] != '"':
                if text[i] == "\\":
                    i += 1
                i += 1
        i += 1
    return -1


def split_top_commas(s):
    out = []
    depth = 0
    start = 0
    i = 0
    while i < len(s):
        c = s[i]
        if c in "{[(":
            depth += 1
        elif c in "}])":
            depth -= 1
        elif c == '"':
            i += 1
            while i < len(s) and s[i] != '"':
                if s[i] == "\\":
                    i += 1
                i += 1
        elif c == "," and depth == 0:
            out.append(s[start:i])
            start = i + 1
        i += 1
    if start < len(s):
        out.append(s[start:])
    return out


def iter_top_braces(s):
    depth = 0
    start = -1
    i = 0
    while i < len(s):
        c = s[i]
        if c == "{":
            if depth == 0:
                start = i
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0 and start >= 0:
                yield s[start + 1 : i]
                start = -1
        elif c == '"':
            i += 1
            while i < len(s) and s[i] != '"':
                if s[i] == "\\":
                    i += 1
                i += 1
        i += 1


def parse_arg(item):
    parts = split_top_commas(item)
    name, typ, optional, default, desc = "", "", "", "", ""
    for i, p in enumerate(parts):
        p_stripped = p.strip()
        if i == 0:
            strs = re.findall(r'"((?:[^"\\]|\\.)*)"', p_stripped, re.DOTALL)
            if strs:
                name = strs[0]
        elif "RPCArg::Type::" in p_stripped:
            m = re.search(r"RPCArg::Type::(\w+)", p_stripped)
            if m and not typ:
                typ = m.group(1)
        elif "RPCArg::Optional::" in p_stripped:
            m = re.search(r"RPCArg::Optional::(\w+)", p_stripped)
            if m and not optional:
                optional = m.group(1)
        elif "RPCArg::Default" in p_stripped:
            m = re.search(r"RPCArg::Default\w*\{([^}]*)\}", p_stripped)
            if m and not default:
                default = m.group(1).strip()
        elif p_stripped.startswith('"') and not desc:
            strs = re.findall(r'"((?:[^"\\]|\\.)*)"', p_stripped, re.DOTALL)
            if strs:
                desc = " ".join(strs)
    return {"name": name, "type": typ, "optional": optional, "default": default, "description": desc}


def parse_helpman(body):
    parts = split_top_commas(body)
    if len(parts) < 2:
        return None
    m = re.search(r'"([a-z][a-z0-9_]*)"', parts[0])
    if not m:
        return None
    name = m.group(1)
    strs = re.findall(r'"((?:[^"\\]|\\.)*)"', parts[1], re.DOTALL)
    desc = "".join(strs).replace("\\n", "\n").strip()
    args = []
    if len(parts) > 2:
        args_text = parts[2].strip()
        if args_text.startswith("{"):
            inner = args_text[1:-1] if args_text.endswith("}") else args_text[1:]
            has_braces = False
            d = 0
            for c in inner:
                if c == "{":
                    if d == 0:
                        has_braces = True
                        break
                    d += 1
                elif c == "}":
                    d -= 1
            if has_braces:
                for block in iter_top_braces(inner):
                    args.append(parse_arg(block))
            else:
                args.append(parse_arg(inner))
    examples = []
    for p in parts:
        for em in re.finditer(
            r'HelpExample(Cli|Rpc)\s*\(\s*"([^"]+)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)', p
        ):
            examples.append(
                (
                    em.group(1),
                    em.group(2),
                    em.group(3).replace('\\"', '"').replace("\\\\", "\\"),
                )
            )
    return {"name": name, "description": desc, "args": args, "examples": examples}


def render(e):
    out = [f"### `{e['name']}`", ""]
    desc_clean = re.sub(r"\n +", "\n", e["description"]).strip()
    if desc_clean:
        for line in desc_clean.split("\n"):
            out.append(line.strip())
        out.append("")
    if e["args"]:
        out.append("**Parameters**")
        out.append("")
        out.append("| # | Name | Type | Required | Description |")
        out.append("| - | ---- | ---- | -------- | ----------- |")
        for i, a in enumerate(e["args"], 1):
            if not a["name"]:
                continue
            if a["optional"] == "NO":
                req = "yes"
            elif a["default"]:
                req = f"no (default `{a['default']}`)"
            else:
                req = "no"
            d = re.sub(r"\s+", " ", a["description"]).strip().replace("|", "\\|")
            out.append(f"| {i} | `{a['name']}` | `{a['type']}` | {req} | {d} |")
        out.append("")
    if e["examples"]:
        out.append("**Examples**")
        out.append("")
        cli = [x for x in e["examples"] if x[0] == "Cli"]
        rpc = [x for x in e["examples"] if x[0] == "Rpc"]
        shown = cli or rpc
        for kind, cmd, args in shown[:2]:
            if kind == "Cli":
                out.append("```bash")
                out.append(f"navio-cli {cmd} {args}".rstrip())
                out.append("```")
            else:
                out.append("```bash")
                out.append(
                    f'curl --user user:pass --data-binary \'{{"jsonrpc":"1.0","id":"curl","method":"{cmd}","params":[{args}]}}\' -H "content-type: text/plain;" http://127.0.0.1:33677/'
                )
                out.append("```")
            out.append("")
    out.append("---")
    out.append("")
    return "\n".join(out)


def main():
    if len(sys.argv) < 2:
        print("usage: extract-blsct-rpc.py <path-to-navio-core>", file=sys.stderr)
        sys.exit(1)
    root = pathlib.Path(sys.argv[1])
    entries = []
    for rel in FILES:
        path = root / rel
        if not path.exists():
            print(f"# warning: {path} not found", file=sys.stderr)
            continue
        text = path.read_text()
        for m in re.finditer(r"RPCHelpMan\s*\{", text):
            end = find_matching(text, m.end() - 1)
            if end < 0:
                continue
            body = text[m.end():end]
            parsed = parse_helpman(body)
            if parsed:
                entries.append(parsed)

    seen = set()
    for e in entries:
        if e["name"] in seen:
            continue
        lc = e["name"].lower()
        if not (any(k in lc for k in BLSCT_KEYWORDS) or e["name"] in EXPLICIT):
            continue
        seen.add(e["name"])
        print(render(e))
    print(f"\n<!-- generated: {len(seen)} commands -->", file=sys.stderr)


if __name__ == "__main__":
    main()
