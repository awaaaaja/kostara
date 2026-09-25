#!/usr/bin/env python3
"""CP-04A tenancy flow tests: TP-TEN-01..06 + isolasi role (submit/activate/end).
Jalankan: python3 scripts/test_tenancy_flow.py  (exit 1 bila ada FAIL)"""

from __future__ import annotations

import json
import pathlib
import sys
import urllib.error
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import run_sql  # noqa: E402

ANON = run_sql.field("ANON_PUBLIC")
SERVICE = run_sql.field("SERVICE_ROLE")
SUPA = f"https://{run_sql.REF}.supabase.co"
PW = "KostaraDev123!"  # dev fixture, bukan secret (Aman.md)

# Property + kamar uji dibuat & dibersihkan khusus test ini (UUID non-seed).
TP = "33333333-0000-4000-8000-000000000001"
RM = "33333333-0000-4000-8000-000000000002"
TP2 = "33333333-0000-4000-8000-000000000011"
RM2 = "33333333-0000-4000-8000-000000000012"
EWKB = "0101000020e61000001f85eb51b81e5940713d0ad7a370edbf"  # POINT(100.48 -0.92)

results: list[tuple[str, str, str]] = []
TOK: dict[str, str] = {}
UID: dict[str, str] = {}


def record(tid: str, ok: bool, detail: str = "") -> None:
    results.append((tid, "PASS" if ok else "FAIL", detail))
    print(f"  {tid}: {'PASS' if ok else 'FAIL'} {detail}")


def req(method: str, url: str, *, apikey: str = ANON, token: str | None = None,
        body=None) -> tuple[int, object]:
    data = body if isinstance(body, bytes) else (
        json.dumps(body).encode() if body is not None else None
    )
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("apikey", apikey)
    r.add_header("Authorization", f"Bearer {token or apikey}")
    if data is not None:
        r.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw) if raw else None
        except json.JSONDecodeError:
            return e.code, raw


def login(email: str) -> str:
    st, out = req("POST", f"{SUPA}/auth/v1/token?grant_type=password",
                  body={"email": email, "password": PW})
    assert st == 200, f"login {email} -> {st} {out}"
    return out["access_token"]


def rest(method: str, path: str, token: str | None = None, *, body=None,
         prefer: bool = False) -> tuple[int, object]:
    st, out = req(method, f"{SUPA}/rest/v1/{path}", token=token, body=body)
    return st, out


def rpc(fn: str, token: str | None = None, body=None) -> tuple[int, object]:
    return req("POST", f"{SUPA}/rest/v1/rpc/{fn}", token=token, body=body or {})


def svc(method: str, path: str, *, body=None) -> tuple[int, object]:
    return req(method, f"{SUPA}/{path}", apikey=SERVICE, token=SERVICE, body=body)


def err_text(out: object) -> str:
    return json.dumps(out).lower()


def cleanup() -> None:
    st, rows = svc(
        "GET",
        f"rest/v1/tenancies?select=id&property_id=in.({TP},{TP2})",
    )
    tids = ",".join(r["id"] for r in (rows or []))
    if tids:
        svc("DELETE", f"rest/v1/payment_records?tenancy_id=in.({tids})")
        svc("DELETE", f"rest/v1/payment_schedules?tenancy_id=in.({tids})")
        svc("DELETE", f"rest/v1/reminders?tenancy_id=in.({tids})")
        svc("DELETE", f"rest/v1/tenancies?id=in.({tids})")
    svc("DELETE", f"rest/v1/tenancy_requests?property_id=in.({TP},{TP2})")
    svc("DELETE", f"rest/v1/rooms?property_id=in.({TP},{TP2})")
    svc("DELETE", f"rest/v1/property_facilities?property_id=in.({TP},{TP2})")
    svc("DELETE", f"rest/v1/property_images?property_id=in.({TP},{TP2})")
    svc("DELETE", f"rest/v1/properties?id=in.({TP},{TP2})")


def setup() -> None:
    for name in ("seeker1", "seeker2", "seeker3", "owner1", "owner2", "admin"):
        tok = login(f"{name}@kostara.dev")
        TOK[name] = tok
        st2, me = req("GET", f"{SUPA}/auth/v1/user", token=tok)
        assert st2 == 200, me
        UID[name] = me["id"]
        results.append((f"login:{name}", "PASS", ""))

    for pid, rid in ((TP, RM), (TP2, RM2)):
        st, out = rest("POST", "properties", TOK["owner1"], body={
            "id": pid, "owner_id": UID["owner1"], "name": "ZZ-TEST Tenancy",
            "address": "Jl Tenancy Test 1", "gender_policy": "any",
            "location": EWKB,
        })
        assert st in (200, 201), f"setup property {st} {out}"
        st, out = svc("PATCH", f"rest/v1/properties?id=eq.{pid}",
                      body={"verification_status": "verified",
                            "listing_status": "active"})
        assert st in (200, 204), f"setup verify {st} {out}"
        st, out = rest("POST", "rooms", TOK["owner1"], body={
            "id": rid, "property_id": pid, "code": "T1",
            "room_type": "single", "price": 1500000,
        })
        assert st in (200, 201), f"setup room {st} {out}"


print("== setup: aktor & fixture ==")
cleanup()
setup()

print("== TP-TEN submit ==")
st, out = rpc("submit_tenancy_request", TOK["seeker1"],
              {"p_property_id": TP, "p_room_id": RM, "p_message": "Mau sewa"})
record("TP-TEN-01 seeker kirim request", st == 200 and out.get("status") == "pending",
       f"{st} {str(out)[:160]}")
req_id = out["id"]

st, out = rpc("submit_tenancy_request", TOK["seeker1"],
              {"p_property_id": TP, "p_room_id": RM})
record("TP-TEN-02 duplikat pending per seeker ditolak",
       st in (400, 409, 422) and "permintaan_pending" in err_text(out),
       f"{st} {str(out)[:160]}")

st, out = rpc("submit_tenancy_request", TOK["seeker2"],
              {"p_property_id": TP, "p_room_id": RM})
record("TP-TEN-03 seeker lain boleh pending di room sama",
       st == 200 and out.get("status") == "pending", f"{st} {str(out)[:160]}")
req2_id = out["id"]

st, out = rpc("submit_tenancy_request", TOK["owner2"],
              {"p_property_id": TP, "p_room_id": RM})
record("TP-TEN-04 owner tidak bisa submit (hanya_seeker)",
       st in (400, 403) and "hanya_seeker" in err_text(out), f"{st} {str(out)[:140]}")

st, out = rpc("submit_tenancy_request", TOK["seeker1"],
              {"p_property_id": "33333333-0000-4000-8000-000000000099",
               "p_room_id": RM})
record("TP-TEN-05 property tak listable ditolak",
       st in (400, 404) and ("tidak_tersedia" in err_text(out)
                             or "tidak_ditemukan" in err_text(out)),
       f"{st} {str(out)[:140]}")

print("== TP-TEN activate: isolasi role ==")
st, out = rpc("activate_tenancy", TOK["seeker1"], {"p_request_id": req_id})
record("TP-TEN-06 seeker tidak boleh activate",
       st in (400, 403) and ("hanya_owner" in err_text(out)
                             or "bukan_pemilik" in err_text(out)),
       f"{st} {str(out)[:140]}")

st, out = rpc("activate_tenancy", TOK["owner2"], {"p_request_id": req_id})
record("TP-TEN-07 owner lain ditolak (bukan_pemilik_property)",
       st in (400, 403) and "bukan_pemilik" in err_text(out), f"{st} {str(out)[:140]}")

st, body = rest("PATCH", f"tenancy_requests?id=eq.{req_id}", TOK["owner1"],
                body={"status": "accepted"})
record("TP-TEN-08 accept via REST langsung ditolak policy",
       st in (400, 403, 409), f"{st} {str(body)[:160]}")

print("== TP-TEN activate: atomik + idempoten ==")
st, out = rpc("activate_tenancy", TOK["owner1"], {"p_request_id": req_id})
record("TP-TEN-09 owner accept → tenancy aktif + schedule",
       st == 200 and out.get("tenancy", {}).get("status") == "active"
       and out.get("next_due_date") is not None,
       f"{st} {str(out)[:200]}")
tid = out.get("tenancy", {}).get("id")

st, rows = svc(
    "GET",
    f"rest/v1/rooms?id=eq.{RM}&select=status",
)
room_status = rows[0]["status"] if rows else "?"
record("TP-TEN-10 room jadi occupied", room_status == "occupied", room_status)

st, rows = svc(
    "GET",
    f"rest/v1/payment_records?tenancy_id=eq.{tid}&select=id,due_date,status&order=due_date",
)
n_due = len(rows or [])
first_due = rows[0]["due_date"] if rows else None
record("TP-TEN-11 12 due date dibuat (FR-PAY-02)",
       st == 200 and n_due == 12 and first_due is not None, f"{st}/{n_due} first={first_due}")

st, rows = svc(
    "GET",
    f"rest/v1/tenancy_requests?id=eq.{req_id}&select=status,decided_by",
)
record("TP-TEN-12 request accepted + decided_by owner1",
       rows and rows[0]["status"] == "accepted"
       and rows[0]["decided_by"] == UID["owner1"], f"{st} {rows}")

st, out = rpc("activate_tenancy", TOK["owner1"], {"p_request_id": req_id})
record("TP-TEN-13 accept ke-2 idempoten (tenancy sama)",
       st == 200 and out.get("tenancy", {}).get("id") == tid,
       f"{st} {str(out)[:160]}")

st, rows = svc(
    "GET",
    f"rest/v1/tenancies?select=id&request_id=eq.{req_id}",
)
record("TP-TEN-14 tepat 1 tenancy per request",
       st == 200 and len(rows or []) == 1, f"{st}/{len(rows or [])}")

print("== TP-TEN cancel / reject / end ==")
st, out = rpc("submit_tenancy_request", TOK["seeker3"],
              {"p_property_id": TP2, "p_room_id": RM2, "p_message": "tiga"})
assert st == 200, f"setup req3 {st} {out}"
req3_id = out["id"]

st, body = rest("PATCH", f"tenancy_requests?id=eq.{req3_id}", TOK["owner1"],
                body={"status": "rejected", "decided_at": "now()"})
record("TP-TEN-15 reject tanpa alasan ditolak CHECK",
       st in (400, 403) and "tenancy_requests_check" in err_text(body),
       f"{st} {str(body)[:160]}")

st, body = rest("PATCH", f"tenancy_requests?id=eq.{req3_id}", TOK["owner1"],
                body={"status": "rejected", "reject_reason": "sudah terisi"})
record("TP-TEN-16 reject dengan alasan ok", st in (200, 204), f"{st} {str(body)[:160]}")

st, body = rest("PATCH", f"tenancy_requests?id=eq.{req2_id}", TOK["seeker2"],
                body={"status": "cancelled"})
record("TP-TEN-17 seeker batalkan request sendiri ok", st in (200, 204),
       f"{st} {str(body)[:160]}")

st, out = rpc("end_tenancy", TOK["owner2"], {"p_tenancy_id": tid})
record("TP-TEN-18 owner lain tidak bisa end",
       st in (400, 403) and "bukan_pemilik" in err_text(out), f"{st} {str(out)[:140]}")

st, out = rpc("end_tenancy", TOK["owner1"], {"p_tenancy_id": tid})
record("TP-TEN-19 owner end → ended + room available",
       st == 200 and out.get("status") == "ended", f"{st} {str(out)[:160]}")

st, rows = svc("GET", f"rest/v1/rooms?id=eq.{RM}&select=status")
record("TP-TEN-20 room kembali available", rows and rows[0]["status"] == "available",
       f"{rows}")

st, out = rpc("end_tenancy", TOK["owner1"], {"p_tenancy_id": tid})
record("TP-TEN-21 end ke-2 idempoten", st == 200 and out.get("status") == "ended",
       f"{st}")

print("== TP-TEN isolasi baca ==")
st, rows = rest("GET", f"tenancies?id=eq.{tid}&select=id", TOK["seeker2"])
record("TP-TEN-22 seeker lain tidak baca tenancy", st == 200 and len(rows or []) == 0,
       f"{st}/{rows}")
st, rows = rest("GET", f"tenancies?id=eq.{tid}&select=id", TOK["seeker1"])
record("TP-TEN-23 seeker terkait baca tenancy", st == 200 and len(rows or []) == 1,
       f"{st}/{len(rows or [])}")
st, rows = rest(
    "GET",
    f"payment_records?tenancy_id=eq.{tid}&select=id",
    TOK["seeker2"],
)
record("TP-TEN-24 seeker lain tidak baca payment (AC-RLS-T1)",
       st == 200 and len(rows or []) == 0, f"{st}/{len(rows or [])}")

print("== cleanup ==")
cleanup()

fails = [r for r in results if r[1] == "FAIL"]
print(f"\n== SUMMARY: {len(results) - len(fails)}/{len(results)} PASS ==")
for tid, _, detail in fails:
    print(f"  FAIL {tid}: {detail}")
sys.exit(1 if fails else 0)
