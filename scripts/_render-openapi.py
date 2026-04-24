#!/usr/bin/env python3
"""Minimal OpenAPI 3.0 → Markdown renderer used as a fallback when `widdershins` isn't available.

Usage:
    python3 _render-openapi.py <openapi.json> <output-dir>
"""
import sys
import json
import pathlib
import re


def slugify(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def schema_to_md(schema, spec, indent=0):
    """Render a schema reference or inline definition as Markdown."""
    if not schema:
        return ""
    if "$ref" in schema:
        ref_name = schema["$ref"].split("/")[-1]
        resolved = spec.get("components", {}).get("schemas", {}).get(ref_name, {})
        return f"`{ref_name}` — " + schema_to_md(resolved, spec, indent)
    t = schema.get("type")
    if t == "object":
        props = schema.get("properties", {})
        required = schema.get("required", [])
        rows = ["| Field | Type | Required | Description |",
                "| ----- | ---- | -------- | ----------- |"]
        for name, prop in props.items():
            prop_type = prop.get("type", prop.get("$ref", "").split("/")[-1] or "any")
            desc = (prop.get("description") or "").replace("\n", " ")
            req = "yes" if name in required else "no"
            rows.append(f"| `{name}` | `{prop_type}` | {req} | {desc} |")
        return "\n".join(rows)
    if t == "array":
        items = schema.get("items", {})
        return "array of " + schema_to_md(items, spec, indent)
    return f"`{t or 'any'}`"


def render(spec, out_dir: pathlib.Path):
    title = spec.get("info", {}).get("title", "Explorer API")
    description = spec.get("info", {}).get("description", "")
    version = spec.get("info", {}).get("version", "")

    index = [
        f"# {title}",
        "",
        f"Version: `{version}`",
        "",
    ]
    if description:
        index.extend([description, ""])

    index.append("| Method | Path | Summary |")
    index.append("| ------ | ---- | ------- |")

    paths = spec.get("paths", {})
    endpoint_pages: list[tuple[str, str]] = []

    for path, methods in sorted(paths.items()):
        for method, op in methods.items():
            if method.lower() not in {"get", "post", "put", "delete", "patch"}:
                continue
            summary = op.get("summary") or op.get("description", "").split("\n")[0]
            slug = slugify(f"{method}-{path}")
            anchor = f"endpoints/{slug}.md"
            index.append(f"| `{method.upper()}` | `{path}` | [{summary or '—'}]({anchor}) |")
            endpoint_pages.append((anchor, render_endpoint(method, path, op, spec)))

    (out_dir / "index.md").write_text("\n".join(index))

    endpoints_dir = out_dir / "endpoints"
    endpoints_dir.mkdir(parents=True, exist_ok=True)
    for name, body in endpoint_pages:
        (out_dir / name).parent.mkdir(parents=True, exist_ok=True)
        (out_dir / name).write_text(body)


def render_endpoint(method: str, path: str, op: dict, spec: dict) -> str:
    lines = [f"# `{method.upper()} {path}`", ""]
    if op.get("summary"):
        lines.extend([op["summary"], ""])
    if op.get("description"):
        lines.extend([op["description"], ""])

    params = op.get("parameters", [])
    if params:
        lines.append("## Parameters")
        lines.append("")
        lines.append("| Name | In | Required | Type | Description |")
        lines.append("| ---- | -- | -------- | ---- | ----------- |")
        for p in params:
            schema = p.get("schema", {})
            lines.append(
                f"| `{p['name']}` | {p.get('in', '')} | "
                f"{'yes' if p.get('required') else 'no'} | "
                f"`{schema.get('type', '')}` | {p.get('description', '')} |"
            )
        lines.append("")

    req_body = op.get("requestBody")
    if req_body:
        lines.append("## Request body")
        lines.append("")
        for ct, content in req_body.get("content", {}).items():
            lines.append(f"`{ct}`:")
            lines.append("")
            lines.append(schema_to_md(content.get("schema", {}), spec))
            lines.append("")

    responses = op.get("responses", {})
    if responses:
        lines.append("## Responses")
        lines.append("")
        for code, resp in sorted(responses.items()):
            lines.append(f"### {code} — {resp.get('description', '')}")
            lines.append("")
            for ct, content in resp.get("content", {}).items():
                lines.append(f"`{ct}`:")
                lines.append("")
                lines.append(schema_to_md(content.get("schema", {}), spec))
                lines.append("")
    return "\n".join(lines)


def main():
    if len(sys.argv) < 3:
        print("usage: _render-openapi.py <spec.json> <out-dir>", file=sys.stderr)
        sys.exit(1)
    spec = json.loads(pathlib.Path(sys.argv[1]).read_text())
    out = pathlib.Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    render(spec, out)


if __name__ == "__main__":
    main()
