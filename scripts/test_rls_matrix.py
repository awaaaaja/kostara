#!/usr/bin/env python3
"""CP-03B REST RLS matrix: TP-RLS-01..07, TP-STOR, TP-REC (feed via REST).
Jalankan: python3 scripts/test_rls_matrix.py  (exit 1 bila ada FAIL)"""

from __future__ import annotations

import base64
import json
import pathlib
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import run_sql  # noqa: E402

ANON = run_sql.field("ANON_PUBLIC")
SERVICE = run_sql.field("SERVICE_ROLE")
SUPA = f"https://{run_sql.REF}.supabase.co"
PW = "KostaraDev123!"  # dev fixture, bukan secret (Aman.md)

P1 = "a0000000-0000-4000-8000-000000000001"
P6 = "a0000000-0000-4000-8000-000000000006"
P11 = "a0000000-0000-4000-8000-000000000011"
T1 = "e0000000-0000-4000-8000-000000000001"
RV4 = "d0000000-0000-4000-8000-000000000004"
TEST_PROP_ID = "22222222-0000-4000-8000-000000000001"
TEST_INT_ID = "22222222-0000-4000-8000-000000000002"
EWKB = "0101000020e61000001f85eb51b81e5940713d0ad7a370edbf"  # POINT(100.48 -0.92) 4326
PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)

results: list[tuple[str, str, str]] = []
TOK: dict[str, str] = {}


def record(tid: str, ok: bool, detail: str = "") -> None:
    results.append((tid, "PASS" if ok else "FAIL", detail))
    print(f"  {tid}: {'PASS' if ok else 'FAIL'} {detail}")


def req(method: str, url: str, *, apikey: str = ANON, token: str | None = None,
        body=None, ctype: str = "application/json",
        prefer: bool = False) -> tuple[int, object]:
    data = body if isinstance(body, bytes) else (
        json.dumps(body).encode() if body is not None else None)

    def build() -> urllib.request.Request:
        r = urllib.request.Request(url, data=data, method=method)
        r.add_header("apikey", apikey)
        r.add_header("Authorization", f"Bearer {token or apikey}")
        if data is not None:
            r.add_header("Content-Type", ctype)
        if prefer:
            r.add_header("Prefer", "return=representation")
        return r

    r = build()
    last: Exception | None = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(r, timeout=60) as resp:
                raw = resp.read()
                if not raw:
                    return resp.status, None
                try:
                    return resp.status, json.loads(raw)
                except (ValueError, UnicodeDecodeError):
                    return resp.status, raw
        except urllib.error.HTTPError as e:
            raw = e.read().decode(errors="replace")
            try:
                return e.code, json.loads(raw)
            except Exception:
                return e.code, raw
        except (ConnectionResetError, TimeoutError, OSError) as e:
            last = e
            time.sleep(1.5 * (attempt + 1))
            r = build()
    raise last  # type: ignore[misc]


def login(email: str) -> str:
    st, out = req("POST", f"{SUPA}/auth/v1/token?grant_type=password",
                  body={"email": email, "password": PW})
    assert st == 200, f"login {email} -> {st} {out}"
    return out["access_token"]


def rest(method: str, path: str, token: str | None = None, *, body=None, apikey: str = ANON,
         prefer: bool = False):
    return req(method, f"{SUPA}/rest/v1/{path}", apikey=apikey, token=token, body=body,
               prefer=prefer)


def rpc(fn: str, token: str | None = None, body=None, apikey: str = ANON):
    return req("POST", f"{SUPA}/rest/v1/rpc/{fn}", apikey=apikey, token=token,
               body=body if body is not None else {})


def svc(method: str, path: str, *, body=None, apikey: str = SERVICE, ctype="application/json"):
    return req(method, f"{SUPA}/{path}", apikey=apikey, token=apikey, body=body, ctype=ctype)


def svc_cleanup(*, extra_user_ids: tuple[str, ...] = (), owner_uid: str | None = None) -> None:
    for u in extra_user_ids:
        svc("DELETE", f"rest/v1/recommendation_logs?user_id=eq.{u}", apikey=SERVICE)
    svc("DELETE", "rest/v1/properties?id=eq." + TEST_PROP_ID, apikey=SERVICE)
    svc("DELETE", "rest/v1/interactions?id=eq." + TEST_INT_ID, apikey=SERVICE)
    svc("DELETE", "rest/v1/audit_logs?action=eq.zz_test", apikey=SERVICE)
    paths = [("property-images", f"{P1}/zz-test.png")]
    if owner_uid:
        paths += [
            ("avatars", f"{owner_uid}/zz-test.png"),
            ("verification-documents-private", f"{owner_uid}/zz-test.png"),
        ]
    for bucket, path in paths:
        svc("DELETE", f"storage/v1/object/{bucket}/{path}", apikey=SERVICE)


print("== login actors ==")
uid = {}
for name, email in [
    ("seeker1", "seeker1@kostara.dev"), ("seeker2", "seeker2@kostara.dev"),
    ("seeker4", "seeker4@kostara.dev"), ("owner1", "owner1@kostara.dev"),
    ("owner2", "owner2@kostara.dev"), ("admin", "admin@kostara.dev"),
]:
    t = login(email)
    TOK[name] = t
    uid[name] = json.loads(base64.urlsafe_b64decode(t.split(".")[1] + "=="))["sub"]
    results.append((f"login:{name}", "PASS", ""))

svc_cleanup(extra_user_ids=(uid['seeker1'], uid['seeker2']), owner_uid=uid['owner1'])

print("== TP-RLS-01 payment visibility ==")
st, out = rest("GET", "payment_schedules?select=tenancy_id", TOK["seeker1"])
record("TP-RLS-01a seeker1 lihat schedule sendiri", st == 200 and len(out) >= 1, f"{st}/{len(out or [])}")
st, out = rest("GET", "payment_schedules?select=id", TOK["seeker2"])
record("TP-RLS-01b seeker2 tidak lihat schedule orang lain", st == 200 and len(out) == 0, f"{st}/{out}")
st, out = rest("GET", "payment_schedules?select=id")
record("TP-RLS-01c anon tidak lihat schedule", st == 200 and len(out or []) == 0, f"{st}/{out}")
st, out = rest("GET", "payment_schedules?select=id", TOK["admin"])
record("TP-RLS-01d admin lihat schedule", st == 200 and len(out) >= 1, f"{st}")
st, out = rest("GET", "payment_records?select=id&tenancy_id=eq." + T1, TOK["seeker1"])
n1 = len(out or [])
st2, out2 = rest("GET", "payment_records?select=id", TOK["seeker2"])
st3, out3 = rest("GET", "payment_records?select=id")
st4, out4 = rest("GET", "payment_records?select=id", TOK["owner1"])
record("TP-RLS-01e payment_records per-tenant/owner/anon",
       n1 == 12 and len(out2 or []) == 0 and len(out3 or []) == 0 and len(out4 or []) == 12,
       f"seeker1={n1} seeker2={len(out2 or [])} anon={len(out3 or [])} owner1={len(out4 or [])}")
# reminders (CP-04B): pihak tenancy vs stranger vs anon (AC-PAY-05)
st, out = rest("GET", "reminders?select=id&tenancy_id=eq." + T1, TOK["seeker1"])
n_rem = len(out or [])
record("TP-RLS-01f reminders pihak lihat miliknya sendiri",
       st == 200 and n_rem >= 1, f"{st}/{n_rem}")
st, out = rest("GET", "reminders?select=id", TOK["seeker2"])
record("TP-RLS-01g reminders stranger kosong",
       st == 200 and len(out or []) == 0, f"{st}/{len(out or [])}")
st, out = rest("GET", "reminders?select=id")
record("TP-RLS-01h reminders anon kosong",
       st == 200 and len(out or []) == 0, f"{st}/{len(out or [])}")
st_pr, out_pr = rest("GET", "payment_records?select=id&tenancy_id=eq." + T1
                     + "&limit=1", TOK["seeker1"])
pr0 = (out_pr or [{}])[0].get("id")
st, body = req("POST", f"{SUPA}/rest/v1/reminders", token=TOK["seeker2"], body={
    "tenancy_id": T1, "payment_record_id": pr0,
    "fire_at": "2026-09-26T02:00:00Z", "offset_days": 13,
    "local_notification_id": "zz-test"})
record("TP-RLS-01i insert reminder atas tenancy lain ditolak",
       st in (401, 403), f"status={st}")

print("== TP-RLS-02 interactions consent gate ==")
st, _ = req("POST", f"{SUPA}/rest/v1/interactions", token=TOK["seeker4"], body={
    "id": TEST_INT_ID, "user_id": uid["seeker4"], "property_id": P1,
    "event_type": "property_view", "source": "app", "occurred_at": "2026-09-25T08:00:00Z"})
record("TP-RLS-02a tanpa consent insert ditolak", st in (401, 403), f"status={st}")
st, _ = req("POST", f"{SUPA}/rest/v1/interactions", token=TOK["seeker1"], body={
    "id": TEST_INT_ID, "user_id": uid["seeker1"], "property_id": P1,
    "event_type": "property_view", "source": "app", "occurred_at": "2026-09-25T08:00:00Z"})
record("TP-RLS-02b dengan consent insert sendiri ok", st in (200, 201), f"status={st}")
st, _ = req("POST", f"{SUPA}/rest/v1/interactions", body={
    "id": "22222222-0000-4000-8000-000000000003", "user_id": "00000000-0000-4000-8000-000000000011",
    "property_id": P1, "event_type": "property_view", "source": "app",
    "occurred_at": "2026-09-25T08:00:00Z"})
record("TP-RLS-02c anon insert ditolak", st in (401, 403), f"status={st}")
st, out = rest("PATCH", f"interactions?id=eq.{TEST_INT_ID}", TOK["seeker2"],
               body={"metadata": {"x": 1}}, prefer=True)
record("TP-RLS-02d ubah interaksi orang lain ditolak",
       (st in (401, 403)) or (st in (200, 204) and not out), f"status={st} {str(out)[:80]}")

print("== TP-RLS-03 profiles ==")
st, out = rest("GET", f"profiles?id=eq.{uid['seeker1']}&select=id", TOK["seeker1"])
record("TP-RLS-03a lihat profil sendiri", st == 200 and len(out) == 1, f"{st}")
st, out = rest("GET", f"profiles?id=eq.{uid['seeker2']}&select=id", TOK["seeker1"])
record("TP-RLS-03b tidak lihat profil lain", st == 200 and len(out) == 0, f"{st}/{out}")
st, out = rest("GET", "profiles?select=id")
record("TP-RLS-03c anon tidak lihat profiles", st == 200 and len(out or []) == 0, f"{st}")
st, out = rest("GET", "profiles_public?select=id")
record("TP-RLS-03d anon lihat profiles_public terbatas", st == 200 and len(out or []) >= 7, f"{st}/{len(out or [])}")
st, body = rest("PATCH", f"profiles?id=eq.{uid['seeker1']}", TOK["seeker1"], body={"role": "super_admin"})
record("TP-RLS-03e self-escalation ditolak guard",
       st in (400, 403) and "profiles_guard" in json.dumps(body), f"status={st} {str(body)[:120]}")
st, _ = rest("PATCH", f"profiles?id=eq.{uid['seeker1']}", TOK["seeker1"],
             body={"phone": "+628119999999"})
st2, _ = rest("PATCH", f"profiles?id=eq.{uid['seeker1']}", TOK["seeker1"], body={"phone": None})
record("TP-RLS-03f edit profil sendiri (non-guard) ok", st in (200, 204) and st2 in (200, 204), f"{st}/{st2}")
st, out = rest("GET", f"profiles?select=full_name&id=eq.{uid['seeker2']}", TOK["seeker2"])
old_name = out[0]["full_name"]
st, out2 = rest("PATCH", f"profiles?id=eq.{uid['seeker2']}", TOK["admin"],
                body={"full_name": old_name + " X"}, prefer=True)
restored = (svc("PATCH", f"rest/v1/profiles?id=eq.{uid['seeker2']}",
                body={"full_name": old_name})[0] in (200, 204))
record("TP-RLS-03g admin ubah profil orang lain (policy admin)",
       st in (200, 204) and isinstance(out2, list) and len(out2) == 1 and restored,
       f"status={st}")

print("== TP-RLS-04 properties ==")
st, out = rest("GET", "properties?select=id", None)
anon_ids = {r["id"] for r in (out or [])}
record("TP-RLS-04a anon hanya lihat active+verified", st == 200 and P11 not in anon_ids and len(anon_ids) == 10,
       f"{st}/{len(anon_ids)}")
st, out = rest("GET", "properties?select=id&limit=50", TOK["owner1"])
o1_ids = {r["id"] for r in (out or [])}
record("TP-RLS-04b owner1 lihat draft sendiri + aktif lain",
       st == 200 and P11 in o1_ids and len(o1_ids) == 11, f"{st}/{len(o1_ids)}")
st, out = rest("GET", "properties?select=id&limit=50", TOK["seeker1"])
s1_ids = {r["id"] for r in (out or [])}
record("TP-RLS-04c seeker tidak lihat draft", st == 200 and P11 not in s1_ids and len(s1_ids) == 10,
       f"{st}/{len(s1_ids)}")
st, out = rest("POST", "properties", TOK["owner1"], body={
    "id": TEST_PROP_ID, "owner_id": uid["owner1"], "name": "ZZ-TEST Prop",
    "address": "Jl ZZ Test No 1", "gender_policy": "any",
    "location": EWKB})
record("TP-RLS-04d owner insert property draft sendiri", st in (200, 201), f"status={st} {str(out)[:150]}")
st, body = rest("PATCH", f"properties?id=eq.{P11}", TOK["owner1"], body={"verification_status": "verified"})
record("TP-RLS-04e owner self-verify ditolak guard",
       st in (400, 403) and "properties_guard" in json.dumps(body), f"status={st}")
st, body = rest("PATCH", f"properties?id=eq.{P11}", TOK["owner1"], body={"listing_status": "active"})
record("TP-RLS-04f active tanpa verified ditolak guard",
       st in (400, 403) and "properties_guard" in json.dumps(body), f"status={st}")
st, _ = rest("POST", "properties", body={
    "owner_id": uid["seeker1"], "name": "ZZ anon", "address": "x", "gender_policy": "any",
    "location": EWKB})
record("TP-RLS-04g anon insert ditolak", st in (401, 403), f"status={st}")

print("== TP-RLS-05 reviews ==")
st, out = rest("GET", "reviews?select=id,status")
record("TP-RLS-05a anon hanya lihat approved", st == 200 and len(out or []) == 3, f"{st}/{len(out or [])}")
st, out = rest("GET", "reviews?select=id,status", TOK["seeker1"])
ids1 = {r["id"] for r in (out or [])}
record("TP-RLS-05b seeker1 lihat semua approved + review sendiri (incl pending)",
       st == 200 and RV4 in ids1 and len(ids1) == 4, f"{st}/{len(ids1)}")
st, _ = rest("POST", "reviews", body={"tenancy_id": T1, "property_id": P1,
                                      "user_id": "00000000-0000-4000-8000-000000000011", "review_type": "pulse",
                                      "rating_overall": 5, "review_text": "anon"})
record("TP-RLS-05c anon insert review ditolak", st in (401, 403), f"status={st}")
st, body = rest("POST", "reviews", TOK["seeker2"], body={
    "tenancy_id": T1, "property_id": P1, "user_id": uid["seeker2"],
    "review_type": "pulse", "rating_overall": 5, "review_text": "bukan tenan saya"})
record("TP-RLS-05d review atas tenancy orang lain ditolak", st in (401, 403), f"status={st} {str(body)[:120]}")
st, out = rpc("fn_can_review", TOK["seeker1"], {"p_tenancy_id": T1, "p_review_type": "pulse"})
st2, out2 = rpc("fn_can_review", TOK["seeker2"], {"p_tenancy_id": T1, "p_review_type": "pulse"})
record("TP-RLS-05e fn_can_review eligibility", st == 200 and out is True and out2 is False,
       f"{st}/{out}/{out2}")
st, _ = rest("PATCH", f"reviews?id=eq.{RV4}", TOK["admin"], body={"status": "approved"})
st2, _ = svc("PATCH", f"rest/v1/reviews?id=eq.{RV4}", body={"status": "pending"})
record("TP-RLS-05f admin moderasi review", st in (200, 204), f"{st}")

print("== TP-RLS-06 tenancies ==")
st, out = rest("GET", "tenancies?select=id", TOK["seeker1"])
n = len(out or [])
st2, out2 = rest("GET", "tenancies?select=id", TOK["seeker2"])
st3, out3 = rest("GET", "tenancies?select=id")
record("TP-RLS-06a tenancy visible per-partai / anon",
       st == 200 and n == 2 and len(out2 or []) == 1 and len(out3 or []) == 0,
       f"s1={n} s2={len(out2 or [])} anon={len(out3 or [])}")
st, _ = rest("POST", "tenancies", TOK["seeker2"], body={
    "property_id": P1, "room_id": "00000000-0000-4000-8000-000000000000",
    "seeker_id": uid["seeker2"], "owner_id": uid["owner1"],
    "start_date": "2026-12-01", "amount": 1000000, "due_day": 1, "status": "active"})
record("TP-RLS-06b insert tenancy tanpa policy ditolak", st in (401, 403), f"status={st}")
st, out = rest("PATCH", f"tenancies?id=eq.{T1}", TOK["seeker1"], body={"amount": 1},
               prefer=True)
record("TP-RLS-06c update tenancy tanpa policy ditolak",
       (st in (401, 403)) or (st in (200, 204) and not out), f"status={st} {str(out)[:80]}")

print("== TP-RLS-07 audit + registry ==")
st, out = rest("GET", "audit_logs?select=id", TOK["admin"])
st2, out2 = rest("GET", "audit_logs?select=id", TOK["seeker1"])
st3, out3 = rest("GET", "audit_logs?select=id")
record("TP-RLS-07a audit_logs hanya admin",
       st == 200 and st2 == 200 and len(out2 or []) == 0 and len(out3 or []) == 0,
       f"admin={len(out or [])} seeker={len(out2 or [])} anon={len(out3 or [])}")
st, out = rest("GET", "model_versions?select=id", TOK["seeker1"])
st2, out2 = rest("GET", "model_versions?select=id", TOK["admin"])
record("TP-RLS-07b model registry hanya admin",
       st == 200 and len(out or []) == 0 and st2 == 200 and len(out2 or []) >= 1,
       f"seeker={len(out or [])} admin={len(out2 or [])}")
st, body = rpc("audit_log_write", TOK["seeker1"], {
    "p_action": "zz_test", "p_target_type": "property", "p_target_id": P1, "p_detail": {}})
record("TP-RLS-07c audit_log_write non-admin ditolak",
       st in (400, 403) and "admin_saja" in json.dumps(body), f"status={st}")
st, body = rpc("audit_log_write", TOK["admin"], {
    "p_action": "zz_test", "p_target_type": "property", "p_target_id": P1, "p_detail": {}})
record("TP-RLS-07d audit_log_write admin ok", st == 200 and isinstance(body, str), f"status={st}")

print("== TP-REC feed via REST ==")
st, out = rpc("feed_recommendations", None, {"p_limit": 5})
items = (out or {}).get("items") if isinstance(out, dict) else None
# feed memakai model aktif bila ada; fallback (baseline-fallback) bila tidak
st_a, act = svc("GET", "rest/v1/model_versions?kind=eq.recommender"
                       "&status=eq.active&select=name")
active_name = (act[0]["name"] if st_a == 200 and isinstance(act, list) and act
               else None)
record("TP-REC-01a anon feed memakai p_limit + model aktif/fallback non-kosong",
       st == 200 and items and len(items) == 5
       and out.get("model_name") in (active_name, "baseline-fallback"),
       f"{st}/{len(items or [])}/{(out or {}).get('model_name')}"
       f"/active={active_name}")
st2, logs_before = rest("GET", "recommendation_logs?select=id", TOK["seeker1"])
st, out = rpc("feed_recommendations", TOK["seeker1"], {"p_limit": 5})
st3, logs_after = rest("GET", "recommendation_logs?select=id", TOK["seeker1"])
delta = len(logs_after or []) - len(logs_before or [])
n_items = len((out or {}).get("items") or [])
record("TP-REC-01b feed authentikasi menulis log per item",
       st == 200 and n_items >= 1 and delta == n_items,
       f"{st}/items={n_items}/log_delta={delta}")

print("== TP-STOR storage policies ==")
st, _ = req("POST", f"{SUPA}/storage/v1/object/avatars/zz/zz-test.png", apikey=ANON,
            token=None, body=PNG, ctype="image/png")
record("TP-STOR-01a anon upload avatars ditolak", st in (400, 401, 403), f"status={st}")
st, _ = req("POST", f"{SUPA}/storage/v1/object/avatars/{uid['owner1']}/zz-test.png",
            token=TOK["owner1"], body=PNG, ctype="image/png")
record("TP-STOR-01b owner upload avatars sendiri ok", st == 200, f"status={st}")
st, _ = req("POST", f"{SUPA}/storage/v1/object/property-images/{P6}/zz-test.png",
            token=TOK["owner1"], body=PNG, ctype="image/png")
record("TP-STOR-01c upload property image milik owner lain ditolak", st in (400, 401, 403), f"status={st}")
st, _ = req("POST", f"{SUPA}/storage/v1/object/property-images/{P1}/zz-test.png",
            token=TOK["owner1"], body=PNG, ctype="image/png")
record("TP-STOR-01d upload property image sendiri ok", st == 200, f"status={st}")
st, _ = req("POST", f"{SUPA}/storage/v1/object/verification-documents-private/{uid['seeker1']}/zz-test.png",
            token=TOK["seeker1"], body=PNG, ctype="image/png")
record("TP-STOR-01e seeker upload dokumen private ditolak", st in (400, 401, 403), f"status={st}")
st, _ = req("POST", f"{SUPA}/storage/v1/object/verification-documents-private/{uid['owner1']}/zz-test.png",
            token=TOK["owner1"], body=PNG, ctype="image/png")
record("TP-STOR-01f owner upload dokumen private ok", st == 200, f"status={st}")
st, _ = req("GET", f"{SUPA}/storage/v1/object/verification-documents-private/{uid['owner1']}/zz-test.png")
record("TP-STOR-01g anon baca dokumen private ditolak", st != 200, f"status={st}")
st, _ = req("GET", f"{SUPA}/storage/v1/object/verification-documents-private/{uid['owner1']}/zz-test.png",
            token=TOK["owner1"])
record("TP-STOR-01h owner baca dokumen private sendiri ok", st == 200, f"status={st}")
st, _ = req("GET", f"{SUPA}/storage/v1/object/verification-documents-private/{uid['owner1']}/zz-test.png",
            token=TOK["seeker1"])
record("TP-STOR-01i seeker lain baca dokumen private ditolak", st != 200, f"status={st}")

print("== TP-RLS-09 price intelligence ==")
# districts: referensi publik baca-saja
st, out = rest("GET", "districts?select=kode")
record("TP-RLS-09a anon baca districts (master aktif)",
       st == 200 and len(out or []) == 11, f"{st}/{len(out or [])}")
st, body = rest("PATCH", "districts?kode=eq.13.71.01", TOK["seeker1"],
                body={"is_active": False})
st_v, val = svc("GET", "rest/v1/districts?kode=eq.13.71.01&select=is_active")
unchanged = isinstance(val, list) and val and val[0]["is_active"] is True
record("TP-RLS-09b update districts ditolak RLS (0 baris)",
       (st in (401, 403) or (st in (200, 204) and not body)) and unchanged,
       f"status={st} still_active={unchanged}")
# room_price_observations: owner-own read; no client write
owner1_uid = json.loads(base64.urlsafe_b64decode(TOK["owner1"].split(".")[1] + "=="))["sub"]
st, own1_prop = svc("GET", f"rest/v1/properties?select=id&owner_id=eq.{owner1_uid}&limit=1")
p_owner1 = (own1_prop or [{}])[0].get("id") or P1
st, out = rest("GET", f"room_price_observations?property_id=eq.{p_owner1}&select=id",
               TOK["owner1"])
n_owner = len(out or [])
st2, out2 = rest("GET", "room_price_observations?select=id", TOK["seeker1"])
st3, out3 = rest("GET", "room_price_observations?select=id")
record("TP-RLS-09c observasi: owner lihat sendiri, stranger/anon kosong",
       st == 200 and n_owner >= 1 and st2 == 200 and not out2
       and st3 == 200 and not out3,
       f"owner={n_owner} seeker={len(out2 or [])} anon={len(out3 or [])}")
st, body = rest("POST", "room_price_observations", TOK["owner1"], body={
    "property_id": p_owner1, "room_id": "00000000-0000-4000-8000-000000000001",
    "monthly_price": 999999, "verification_status": "verified",
    "source_type": "system"})
record("TP-RLS-09d insert observasi client ditolak (server-only)",
       st in (401, 403), f"status={st}")
# price_estimates: tulis server-only; owner-own read; seeker hanya lewat view
PE_ID = "22222222-0000-4000-8000-000000000009"
svc("DELETE", f"rest/v1/price_estimates?id=eq.{PE_ID}")
st_r, room1 = svc("GET", f"rest/v1/rooms?property_id=eq.{p_owner1}"
                            "&select=id,price&limit=1")
room_o1 = (room1 or [{}])[0]
st_b, body_b = svc("POST", "rest/v1/price_estimates", body=[{
    "id": PE_ID, "room_id": room_o1.get("id"), "property_id": p_owner1,
    "status": "ok", "model_version": "rls-fixture", "actual_price": 1000000,
    "estimated_lower": 900000, "estimated_point": 1000000,
    "estimated_upper": 1100000, "quality_status": "SUFFICIENT_DATA",
    "price_position": "WITHIN_COMPARABLE_RANGE"}])
st, body = rest("POST", "price_estimates", TOK["owner1"], body={
    "room_id": room_o1.get("id"), "property_id": p_owner1, "status": "ok",
    "actual_price": 1000000})
record("TP-RLS-09e insert estimasi client ditolak (server-only)",
       st in (401, 403), f"status={st} fixture={st_b}")
st, out = rest("GET", f"price_estimates?id=eq.{PE_ID}&select=id", TOK["owner1"])
st2, out2 = rest("GET", "price_estimates?select=id", TOK["seeker1"])
st3, out3 = rest("GET", "price_estimates?select=id", TOK["admin"])
record("TP-RLS-09f estimasi: owner lihat, seeker kosong, admin lihat",
       st == 200 and len(out or []) == 1 and st2 == 200 and not out2
       and st3 == 200 and len(out3 or []) >= 1,
       f"owner={len(out or [])} seeker={len(out2 or [])} admin={len(out3 or [])}")
st, body = rest("PATCH", f"price_estimates?id=eq.{PE_ID}", TOK["owner1"],
                body={"price_position": "ABOVE_RANGE"})
st_v, val = svc("GET", f"rest/v1/price_estimates?id=eq.{PE_ID}&select=price_position")
unchanged = isinstance(val, list) and val and val[0]["price_position"] == "WITHIN_COMPARABLE_RANGE"
record("TP-RLS-09g update estimasi client ditolak (0 baris)",
       (st in (401, 403) or (st in (200, 204) and not body)) and unchanged,
       f"status={st} pos={val}")
st, out = rest("GET", f"price_insight_public?room_id=eq.{room_o1.get('id')}&select=*")
cols = set((out or [{}])[0].keys()) if out else set()
record("TP-RLS-09h view publik: label saja, tanpa angka estimasi",
       st == 200 and len(out or []) == 1
       and cols <= {"room_id", "price_position", "quality_status", "generated_at"},
       f"{st}/{sorted(cols)}")
svc("DELETE", f"rest/v1/price_estimates?id=eq.{PE_ID}")

svc_cleanup(extra_user_ids=(uid['seeker1'], uid['seeker2']), owner_uid=uid['owner1'])

fails = [x for x in results if x[1] == "FAIL"]
print(f"\n== SUMMARY: {len(results) - len(fails)}/{len(results)} PASS ==")
for tid, st_, det in fails:
    print(f"  FAIL {tid}: {det}")
sys.exit(1 if fails else 0)
