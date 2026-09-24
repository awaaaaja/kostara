#!/usr/bin/env python3
"""Self-check split_statements (parser) — jalankan: python3 scripts/test_run_sql_split.py"""

from run_sql import split_statements

assert len(split_statements("select 1; select 2;")) == 2
assert len(split_statements("select 'a;b';")) == 1
assert len(split_statements("select 'it''s; fine';")) == 1
assert len(split_statements("select 1 -- comment; still comment\n; select 2")) == 2
assert len(split_statements("-- leading comment; with semi\nselect 1;")) == 1
assert len(
    split_statements(
        "create function f() returns int as $$ begin null; end; $$ language plpgsql;"
    )
) == 1
assert split_statements("select '--not a comment';")[0].startswith("select")
print("split_statements ok")
