#!/usr/bin/env python3
"""CP-03B dev seed — SINTETIS, HANYA UNTUK ENVIRONMENT DEV.

Membuat user auth (admin/owner/seeker) lalu menjalankan seed_data.sql
(fixed uuid, idempotent). Data = karangan dev untuk uji RLS/spatial/ML.

Usage: python3 supabase/seed/seed_dev.py
"""

import json
import pathlib
import re
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import run_sql  # noqa: E402  (parses Aman.md)

AMAN = run_sql.AMAN
REF = run_sql.REF
URL = f"https://{REF}.supabase.co"

PASSWORD = "KostaraDev123!"  # DEV FIXTURE ONLY — bukan secret produksi

USERS = [
    ("admin@kostara.dev", "Super Admin KOSTARA", "seeker", True),
    ("owner1@kostara.dev", "Owner Melati", "owner", True),
    ("owner2@kostara.dev", "Owner Eltis", "owner", True),
    ("seeker1@kostara.dev", "Sari Mahasiswi", "seeker", True),
    ("seeker2@kostara.dev", "Andi Mahasiswa", "seeker", True),
    ("seeker3@kostara.dev", "Rina Mahasiswi", "seeker", True),
    ("seeker4@kostara.dev", "Budi Tanpa Consent", "seeker", False),
]
PLACEHOLDER = {
    "{{ADMIN}}": "admin@kostara.dev",
    "{{OWNER1}}": "owner1@kostara.dev",
    "{{OWNER2}}": "owner2@kostara.dev",
    "{{SEEKER1}}": "seeker1@kostara.dev",
    "{{SEEKER2}}": "seeker2@kostara.dev",
    "{{SEEKER3}}": "seeker3@kostara.dev",
    "{{SEEKER4}}": "seeker4@kostara.dev",
}


def field(name: str) -> str:
    m = re.search(rf"^{name}:\s*(\S+)", AMAN, re.M)
    if not m:
        raise SystemExit(f"field {name} not found in Aman.md")
    return m.group(1)


SERVICE_ROLE = field("SERVICE_ROLE")


def rest(method: str, path: str, payload: dict | None = None) -> dict:
    req = urllib.request.Request(
        f"{URL}{path}",
        data=json.dumps(payload).encode() if payload is not None else None,
        headers={
            "apikey": SERVICE_ROLE,
            "Authorization": f"Bearer {SERVICE_ROLE}",
            "Content-Type": "application/json",
        },
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        raise SystemExit(f"{method} {path} -> HTTP {e.code}: {body}") from None


def existing_user_ids() -> dict[str, str]:
    users: dict[str, str] = {}
    page = 1
    while True:
        data = rest("GET", f"/auth/v1/admin/users?page={page}&per_page=200")
        for u in data.get("users", []):
            users[u["email"]] = u["id"]
        if len(data.get("users", [])) < 200:
            return users
        page += 1


def ensure_users() -> dict[str, str]:
    ids = existing_user_ids()
    for email, full_name, role, consent in USERS:
        if email in ids:
            print(f"  exists: {email}")
            continue
        payload = {
            "email": email,
            "password": PASSWORD,
            "email_confirm": True,
            "user_metadata": {
                "full_name": full_name,
                "role": role,
                "tos_version": "v1.0",
                "tos_accepted_at": "2026-09-25T00:00:00+07:00",
                "data_consent": consent,
            },
        }
        created = rest("POST", "/auth/v1/admin/users", payload)
        ids[email] = created["id"]
        print(f"  created: {email}")
    return ids


def main() -> None:
    print("== ensure auth users ==")
    ids = ensure_users()

    tmpl = (ROOT / "supabase" / "seed" / "seed_data.sql").read_text()
    for placeholder, email in PLACEHOLDER.items():
        tmpl = tmpl.replace(placeholder, ids[email])

    print("== run seed_data.sql ==")
    out = []
    for stmt in run_sql.split_statements(tmpl):
        out.append(run_sql.run(stmt))
    print(json.dumps(out[-1], indent=2, ensure_ascii=False))  # ringkasan
    print("seed done")


if __name__ == "__main__":
    main()
