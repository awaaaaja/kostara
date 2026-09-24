#!/usr/bin/env python3
"""Run SQL against the linked Supabase project via the Management API.

Usage:
  python3 scripts/run_sql.py migration.sql   # runs each statement in order
  echo "select 1" | python3 scripts/run_sql.py -

Supabase Management API accepts one statement per call, so multi-statement
files are split with a dollar-quote-aware splitter (safe for $$ ... $$ bodies).
"""

import json
import pathlib
import re
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
AMAN = (ROOT / "Aman.md").read_text()


def field(name: str) -> str:
    m = re.search(rf"^{name}:\s*(\S+)", AMAN, re.M)
    if not m:
        raise SystemExit(f"field {name} not found in Aman.md")
    return m.group(1)


TOKEN = field("Supabase_Access_Token")
REF = field("PROJECT_REF")


def split_statements(sql: str) -> list[str]:
    """Split on ';' — ignores ';' inside dollar-quoted bodies, 'strings', --comments."""
    stmts, buf = [], []
    i, n = 0, len(sql)
    tag = None
    in_str = False
    in_comment = False
    while i < n:
        ch = sql[i]
        if in_comment:
            buf.append(ch)
            i += 1
            if ch == "\n":
                in_comment = False
            continue
        if tag is None and not in_str and sql.startswith("--", i):
            in_comment = True
            buf.append("--")
            i += 2
            continue
        if in_str:
            buf.append(ch)
            if ch == "'":
                if i + 1 < n and sql[i + 1] == "'":
                    buf.append("'")
                    i += 2
                    continue
                in_str = False
            i += 1
            continue
        if tag is None and ch == "'":
            in_str = True
            buf.append(ch)
            i += 1
            continue
        if tag is None and sql.startswith("$$", i):
            tag = "$$"
            buf.append("$$")
            i += 2
            continue
        if tag == "$$" and sql.startswith("$$", i):
            tag = None
            buf.append("$$")
            i += 2
            continue
        if tag is None:
            m = re.match(r"\$[A-Za-z_]*\$", sql[i:])
            if m:
                tag = m.group(0)
                buf.append(tag)
                i += len(tag)
                continue
        if tag and sql.startswith(tag, i):
            buf.append(tag)
            i += len(tag)
            tag = None
            continue
        if tag is None and ch == ";":
            stmts.append("".join(buf))
            buf = []
            i += 1
            continue
        buf.append(ch)
        i += 1
    tail = "".join(buf).strip()
    if tail:
        stmts.append(tail)
    # drop empty / comment-only statements (keep leading comments attached to SQL)
    out = []
    for s in stmts:
        body = [l for l in s.splitlines() if l.strip() and not l.strip().startswith("--")]
        if body:
            out.append(s.strip())
    return out


def run(sql: str) -> object:
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{REF}/database/query",
        data=json.dumps({"query": sql}).encode(),
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        raise SystemExit(f"HTTP {e.code}: {body}") from None


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] != "-":
        sql = pathlib.Path(sys.argv[1]).read_text()
    else:
        sql = sys.stdin.read()
    results = []
    for stmt in split_statements(sql):
        out = run(stmt)
        results.append(out)
    print(json.dumps(results, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
