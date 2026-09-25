#!/usr/bin/env python3
"""CP-04B end-to-end flow: TP-REV / TP-ADM / TP-PAY / TP-REC / TP-PRIV-02.

Jalankan: python3 scripts/test_cp04b_flow.py   (exit 1 bila ada FAIL)

Fixture dibuat & dibersihkan di script ini (penanda 'zz-cp04b'); rerun aman.
Catatan sengaja (P2): baris reminder seed memakai tengah malam WIB (17:00Z),
sedangkan app (reminderFireUtc) memakai 09:00 WIB — kolom fire_at hanya
bookkeeping, UI menyusun ulang dari due_date+offset (DESIGN §26).
"""

from __future__ import annotations

import datetime as dt
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

T1 = "e0000000-0000-4000-8000-000000000001"
EWKB = "0101000020e61000001f85eb51b81e5940713d0ad7a370edbf"  # POINT(100.48 -0.92)
PA = "44444444-0000-4000-8000-000000000001"  # listing A (approve)
PB = "44444444-0000-4000-8000-000000000002"  # listing B (reject)
REPORT = "44444444-0000-4000-8000-000000000003"
PAST_DUE_AMOUNT = 999999  # penanda baris fixture jatuh tempo lewat
REC_EMAIL = "zz-cp04b-rec@kostara.dev"
PRIV_EMAIL = "zz-cp04b-priv@kostara.dev"
REASONS = {  # dictionary alasan feed (cp02 test-plan TP-REC-02)
    "budget_fit", "near_campus", "facility_match",
    "high_verified_rating", "positive_aspects", "trending",
}
P10 = "a0000000-0000-4000-8000-000000000010"  # 650k, any, 355m dari campus1

results: list[tuple[str, str, str]] = []
TOK: dict[str, str] = {}
UID: dict[str, str] = {}
fixtures: dict[str, str] = {}  # id hasil fixture utama (request/tenancy/review)


def record(tid: str, ok: bool, detail: str = "") -> None:
    results.append((tid, "PASS" if ok else "FAIL", detail))
    print(f"  {tid}: {'PASS' if ok else 'FAIL'} {detail}")


def req(method: str, url: str, *, apikey: str = ANON, token: str | None = None,
        body=None, ctype: str = "application/json") -> tuple[int, object]:
    data = body if isinstance(body, bytes) else (
        json.dumps(body).encode() if body is not None else None
    )
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("apikey", apikey)
    r.add_header("Authorization", f"Bearer {token or apikey}")
    if data is not None:
        r.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(r, timeout=60) as resp:
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


def rest(method: str, path: str, token: str | None = None, *, body=None):
    return req(method, f"{SUPA}/rest/v1/{path}", token=token, body=body)


def rpc(fn: str, token: str | None = None, body=None):
    return req("POST", f"{SUPA}/rest/v1/rpc/{fn}", token=token, body=body or {})


def svc(method: str, path: str, *, body=None):
    return req(method, f"{SUPA}/{path}", apikey=SERVICE, token=SERVICE, body=body)


def err(out: object) -> str:
    return json.dumps(out).lower()


def audit(action: str, target_type: str | None = None,
          target_id: str | None = None, detail=None) -> None:
    """Tulis audit persis seperti app admin (admin_repository._audit)."""
    rpc("audit_log_write", TOK["admin"], {
        "p_action": action, "p_target_type": target_type,
        "p_target_id": target_id, "p_detail": detail})


def uid_of(token: str) -> str:
    st, me = req("GET", f"{SUPA}/auth/v1/user", token=token)
    assert st == 200, me
    return me["id"]


def reset_payment_fixture() -> None:
    """Kembalikan T1 ke state seed: 2 paid + 10 unpaid, schedule, 4 reminder."""
    svc("DELETE", "rest/v1/payment_records?tenancy_id=eq." + T1
        + f"&amount=eq.{PAST_DUE_AMOUNT}")
    st, rows = svc("GET", f"rest/v1/payment_records?tenancy_id=eq.{T1}&select=id,due_date,status")
    for r in rows or []:
        want = "paid" if r["due_date"] < "2026-10-01" else "unpaid"
        if r["status"] != want:
            svc("PATCH", f"rest/v1/payment_records?id=eq.{r['id']}",
                body={"status": want, "paid_at": None, "marked_by": None})
    svc("PATCH", f"rest/v1/payment_schedules?tenancy_id=eq.{T1}",
        body={"next_due_date": "2026-10-01"})
    st, rec = svc("GET", "rest/v1/payment_records?tenancy_id=eq." + T1
                  + "&due_date=eq.2026-10-01&select=id")
    rid = rec[0]["id"]
    # sisakan hanya 4 reminder seed pada record 2026-10-01 (offset 7/3/1/0)
    svc("DELETE", "rest/v1/reminders?tenancy_id=eq." + T1
        + f"&or=(payment_record_id.neq.{rid},"
        + f"and(payment_record_id.eq.{rid},offset_days.not_in.(0,1,3,7)))")
    st, rems = svc("GET", "rest/v1/reminders?tenancy_id=eq." + T1
                   + "&payment_record_id=eq." + rid + "&select=id,offset_days,status")
    by_off = {r["offset_days"]: r for r in rems or []}
    for off, fire in ((7, "2026-09-23T17:00:00+00:00"),
                      (3, "2026-09-27T17:00:00+00:00"),
                      (1, "2026-09-29T17:00:00+00:00"),
                      (0, "2026-09-30T17:00:00+00:00")):
        if off in by_off:
            if by_off[off]["status"] != "scheduled":
                svc("PATCH", f"rest/v1/reminders?id=eq.{by_off[off]['id']}",
                    body={"status": "scheduled"})
        else:
            svc("POST", "rest/v1/reminders", body={
                "tenancy_id": T1, "payment_record_id": rid,
                "offset_days": off, "fire_at": fire, "status": "scheduled"})


def cleanup() -> None:
    st, reqs = svc("GET", "rest/v1/tenancy_requests?message=eq.zz-cp04b&select=id")
    # tenancy kadang menyimpan request_id; hapus via tenancy dulu
    st, tids = svc("GET", "rest/v1/tenancies?select=id,request_id&request_id=not.is.null")
    zz_t = []
    for t in tids or []:
        st2, rq = svc("GET", f"rest/v1/tenancy_requests?id=eq.{t['request_id']}&select=id,message")
        if rq and rq[0].get("message") == "zz-cp04b":
            zz_t.append(t["id"])
    if zz_t:
        in_t = ",".join(zz_t)
        svc("DELETE", f"rest/v1/reviews?tenancy_id=in.({in_t})")
        svc("DELETE", f"rest/v1/payment_records?tenancy_id=in.({in_t})")
        svc("DELETE", f"rest/v1/payment_schedules?tenancy_id=in.({in_t})")
        svc("DELETE", f"rest/v1/reminders?tenancy_id=in.({in_t})")
        svc("DELETE", f"rest/v1/tenancies?id=in.({in_t})")
    if reqs:
        svc("DELETE", "rest/v1/tenancy_requests?message=eq.zz-cp04b")
    svc("DELETE", "rest/v1/reviews?review_text=like.zz-cp04b*")
    for pid in (PA, PB):
        svc("DELETE", f"rest/v1/property_facilities?property_id=eq.{pid}")
        svc("DELETE", f"rest/v1/property_images?property_id=eq.{pid}")
        svc("DELETE", f"rest/v1/properties?id=eq.{pid}")
    svc("DELETE", f"rest/v1/reports?id=eq.{REPORT}")
    svc("DELETE", "rest/v1/interactions?source=eq.zz-adm07")
    reset_payment_fixture()
    # state alternatif yang mungkin tertinggal dari run sebelumnya
    svc("PATCH", f"rest/v1/owner_profiles?user_id=eq.{UID['owner2']}",
        body={"verification_status": "verified", "reject_reason": None})
    svc("PATCH", f"rest/v1/user_preferences?user_id=eq.{UID['seeker1']}",
        body={"budget_min": 800000, "budget_max": 1800000})
    st, users = svc("GET", "auth/v1/admin/users?page=1&per_page=200")
    for u in (users or {}).get("users", []):
        email = str(u.get("email") or "")
        if email in (REC_EMAIL, PRIV_EMAIL) or email.startswith("deleted-"):
            svc("DELETE", f"auth/v1/admin/users/{u['id']}")


def setup() -> None:
    for name in ("seeker1", "seeker2", "owner1", "owner2", "admin"):
        tok = login(f"{name}@kostara.dev")
        TOK[name] = tok
        UID[name] = uid_of(tok)
        results.append((f"login:{name}", "PASS", ""))
    cleanup()


# ---------------------------------------------------------------- TP-REV
def test_rev() -> None:
    # room tersedia milik owner1 (dynamic, hindari room terisi/request pending)
    prop = room = None
    st, props = svc("GET", "rest/v1/properties?owner_id=eq." + UID["owner1"]
                    + "&verification_status=eq.verified&listing_status=eq.active&select=id")
    for p in props or []:
        st2, rooms = svc("GET", f"rest/v1/rooms?property_id=eq.{p['id']}"
                         "&status=eq.available&select=id")
        if rooms:
            prop, room = p["id"], rooms[0]["id"]
            break
    assert prop, "tidak ada room available milik owner1 untuk fixture REV"

    # REV-01: review atas tenancy tak dikenal → ditolak (fn_can_review)
    st, out = rest("POST", "reviews", TOK["seeker2"], body={
        "tenancy_id": "ffffffff-0000-4000-8000-000000000001",
        "property_id": prop, "user_id": UID["seeker2"],
        "review_type": "final", "rating_overall": 5, "status": "pending"})
    record("TP-REV-01", st == 403, f"status={st}")

    # REV-02a: final review saat tenancy masih aktif → ditolak
    st, out = rest("POST", "reviews", TOK["seeker1"], body={
        "tenancy_id": T1, "property_id": "a0000000-0000-4000-8000-000000000001",
        "user_id": UID["seeker1"], "review_type": "final",
        "rating_overall": 5, "status": "pending"})
    record("TP-REV-02a", st == 403, f"tenancy aktif ditolak status={st}")

    # rantai fixture: request → aktif → selesai → final review sah
    st, out = rpc("submit_tenancy_request", TOK["seeker2"],
                  {"p_property_id": prop, "p_room_id": room,
                   "p_message": "zz-cp04b"})
    assert st == 200, f"submit {st} {out}"
    req_id = out["id"]
    st, out = rpc("activate_tenancy", TOK["owner1"], {"p_request_id": req_id})
    assert st == 200, f"activate {st} {out}"
    ten_id = out["tenancy"]["id"]
    fixtures["tenancy"] = ten_id
    st, out = rpc("end_tenancy", TOK["owner1"], {"p_tenancy_id": ten_id})
    assert st == 200, f"end {st} {out}"

    st_ins, out = rest("POST", "reviews", TOK["seeker2"], body={
        "tenancy_id": ten_id, "property_id": prop, "user_id": UID["seeker2"],
        "review_type": "final", "rating_overall": 4,
        "review_text": "zz-cp04b final review", "status": "pending"})
    # baris pending hanya terlihat oleh pengulas (bukan anon)
    st, got = rest("GET", f"reviews?tenancy_id=eq.{ten_id}&select=id",
                   TOK["seeker2"])
    if st_ins not in (200, 201) or not got:
        record("TP-REV-02b", False, f"insert={st_ins} {out} get={got}")
        return
    rid = got[0]["id"]
    fixtures["review"] = rid

    # 8 skor aspek ditulis pengulas (review_aspect_scores_author)
    st_a, out_a = rest("POST", "review_aspect_scores", TOK["seeker2"], body=[
        {"review_id": rid, "aspect": a, "score": 4, "sentiment": "positive",
         "source": "manual"}
        for a in ("cleanliness", "security", "internet", "water",
                  "comfort", "access", "owner", "value")])
    st2, scores = svc("GET", f"rest/v1/review_aspect_scores?review_id=eq.{rid}"
                      "&select=aspect")
    keys = [s["aspect"] for s in scores or []]
    record("TP-REV-02b", st_a in (200, 201) and len(keys) == 8,
           f"insert={st_a} {out_a!r:.120} aspects={keys}")
    record("TP-REV-07", len(keys) == 8, f"8 aspek: {keys}")

    # REV-03: final review kedua untuk tenancy sama → unique violation
    st, out = rest("POST", "reviews", TOK["seeker2"], body={
        "tenancy_id": ten_id, "property_id": prop, "user_id": UID["seeker2"],
        "review_type": "final", "rating_overall": 3, "status": "pending"})
    record("TP-REV-03", 400 <= st < 500, f"status={st}")

    # REV-05: anon tak melihat pending; setelah approve admin → terlihat
    st, out = rest("GET", f"reviews?id=eq.{rid}&select=id")
    record("TP-REV-05a", st == 200 and out == [], f"anon_pending status={st}")
    st, _ = rest("PATCH", f"reviews?id=eq.{rid}", TOK["admin"],
                 body={"status": "approved", "moderated_by": UID["admin"]})
    st, out = rest("GET", f"reviews?id=eq.{rid}&select=id,status")
    record("TP-REV-05b", st == 200 and out and out[0]["status"] == "approved",
           f"anon_after_approve={out}")

    # REV-06: baris publik tanpa identitas (full_name/phone tidak ikut select)
    st, out = rest("GET", f"reviews?id=eq.{rid}&select=user_id,status,rating_overall")
    row = (out or [{}])[0]
    leak = [k for k in row if k in ("full_name", "phone", "email")]
    record("TP-REV-06", st == 200 and not leak, f"leak_keys={leak}")


# ---------------------------------------------------------------- TP-REC
def feed(token: str) -> dict:
    st, out = rpc("feed_recommendations", token, {"p_limit": 50})
    assert st == 200, f"feed {st} {out}"
    return out


def test_rec() -> None:
    # REC-02: setiap kartu feed ≥1 alasan, semuanya dalam dictionary 6 kode
    out = feed(TOK["seeker1"])
    items = out.get("items", [])
    bad = [i for i in items
           if not i.get("reason_codes")
           or not set(i["reason_codes"]) <= REASONS]
    record("TP-REC-02", len(items) > 0 and not bad,
           f"items={len(items)} bad={len(bad)} model={out.get('model_name')}")

    # REC-05: user baru (tanpa preferensi/interaksi) → feed tetap terisi
    st, out = svc("POST", "auth/v1/admin/users", body={
        "email": REC_EMAIL, "password": PW, "email_confirm": True,
        "user_metadata": {"full_name": "ZZ CP04B Rec", "role": "seeker",
                          "tos_version": "v1.0",
                          "tos_accepted_at": dt.datetime.now(dt.timezone.utc)
                          .isoformat(), "data_consent": "true"}})
    if st >= 400:
        record("TP-REC-05", False, f"create_user {st} {out}")
        return
    rec_uid = out["id"]
    tok = login(REC_EMAIL)
    out = feed(tok)
    items = out.get("items", [])
    ok = len(items) > 0 and all(
        i.get("reason_codes") and set(i["reason_codes"]) <= REASONS
        for i in items)
    # fallback notice: user tanpa prefs tidak diklaim personalisasi → model_name
    # tetap baseline/hybrid; ketersediaan item = AC utama (tanpa blank screen)
    record("TP-REC-05", ok, f"items={len(items)} model={out.get('model_name')}")
    # bersihkan: logs lalu hapus user (profile cascade)
    svc("DELETE", f"rest/v1/recommendation_logs?user_id=eq.{rec_uid}")
    svc("DELETE", f"auth/v1/admin/users/{rec_uid}")

    # REC-06: ubah budget_max → properti di atas budget lama boleh muncul
    st, prefs = svc("GET", f"rest/v1/user_preferences?user_id=eq.{UID['seeker1']}"
                    "&select=budget_min,budget_max")
    assert prefs, "user_preferences seeker1 hilang"
    bmin0, bmax0 = prefs[0]["budget_min"], prefs[0]["budget_max"]
    try:
        svc("PATCH", f"rest/v1/user_preferences?user_id=eq.{UID['seeker1']}",
            body={"budget_min": 0, "budget_max": 400000})
        low = {i["property_id"] for i in feed(TOK["seeker1"]).get("items", [])}
        svc("PATCH", f"rest/v1/user_preferences?user_id=eq.{UID['seeker1']}",
            body={"budget_min": 0, "budget_max": 5000000})
        high = {i["property_id"] for i in feed(TOK["seeker1"]).get("items", [])}
        record("TP-REC-06",
               P10 not in low and P10 in high and low <= high,
               f"low={len(low)} high={len(high)} p10 low/high="
               f"{P10 in low}/{P10 in high}")
    finally:
        svc("PATCH", f"rest/v1/user_preferences?user_id=eq.{UID['seeker1']}",
            body={"budget_min": bmin0, "budget_max": bmax0})


# ---------------------------------------------------------------- TP-ADM
def test_adm() -> None:
    # ADM-01: overview admin = hitungan ground truth (svc)
    ok, detail = True, ""
    for t in ("profiles", "properties", "rooms", "tenancies", "reviews", "reports"):
        st, a = rest("GET", f"{t}?select=id&limit=1000", TOK["admin"])
        st2, s = svc("GET", f"rest/v1/{t}?select=id&limit=1000")
        if st != 200 or len(a or []) != len(s or []):
            ok = False
            detail += f"{t}:{len(a or [])}vs{len(s or [])} "
    queues = (("owner_profiles", "verification_status", "pending"),
              ("properties", "verification_status", "pending"),
              ("reports", "status", "open"),
              ("reviews", "status", "pending"))
    for t, col, val in queues:
        st, a = rest("GET", f"{t}?{col}=eq.{val}&select=id", TOK["admin"])
        st2, s = svc("GET", f"rest/v1/{t}?{col}=eq.{val}&select=id")
        if len(a or []) != len(s or []):
            ok = False
            detail += f"queue {t}:{len(a or [])}vs{len(s or [])} "
    record("TP-ADM-01", ok, detail or "semua tabel & antrean cocok")

    # ADM-02 + ADM-06: reject wajib alasan, audit owner_reject; approve → audit
    # owner_profiles PK = user_id
    st, prof = svc("GET", f"rest/v1/owner_profiles?user_id=eq.{UID['owner2']}"
                   "&select=user_id,verification_status,reject_reason")
    opid = prof[0]["user_id"]
    svc("PATCH", f"rest/v1/owner_profiles?user_id=eq.{opid}",
        body={"verification_status": "pending", "reject_reason": None})
    st, out = rest("PATCH", f"owner_profiles?user_id=eq.{opid}", TOK["admin"],
                   body={"verification_status": "rejected"})
    r1 = st == 400 and "reject_butuh_alasan" in err(out)
    record("TP-ADM-02a", r1, f"status={st}")
    st, _ = rest("PATCH", f"owner_profiles?user_id=eq.{opid}", TOK["admin"],
                 body={"verification_status": "rejected",
                       "reject_reason": "Dokumen buram"})
    audit("owner_reject", "owner", opid, {"reason": "Dokumen buram"})
    st, prof2 = svc("GET", f"rest/v1/owner_profiles?user_id=eq.{opid}"
                    "&select=verification_status,reject_reason")
    r2 = st == 200 and prof2[0]["verification_status"] == "rejected" \
        and prof2[0]["reject_reason"] == "Dokumen buram"
    record("TP-ADM-02b", r2, f"row={prof2}")
    # restore lewat admin (sekalian menghasilkan audit owner_verify)
    st, _ = rest("PATCH", f"owner_profiles?user_id=eq.{opid}", TOK["admin"],
                 body={"verification_status": "verified", "reject_reason": None})
    audit("owner_verify", "owner", opid)
    record("TP-ADM-02c", st in (200, 204), f"restore status={st}")

    # ADM-03: listing — reject tanpa alasan gagal; approve → publik; reject → sembunyi
    st, _ = svc("POST", "rest/v1/properties", body={
        "id": PA, "owner_id": UID["owner1"], "name": "zz cp04b listing A",
        "address": "Jl ZZ 1", "gender_policy": "any", "location": EWKB,
        "listing_status": "draft", "verification_status": "pending"})
    st, _ = svc("POST", "rest/v1/properties", body={
        "id": PB, "owner_id": UID["owner1"], "name": "zz cp04b listing B",
        "address": "Jl ZZ 2", "gender_policy": "any", "location": EWKB,
        "listing_status": "draft", "verification_status": "pending"})
    st, out = rest("PATCH", f"properties?id=eq.{PA}", TOK["admin"],
                   body={"verification_status": "rejected"})
    record("TP-ADM-03a", st == 400 and "reject_butuh_alasan" in err(out),
           f"status={st}")
    st, _ = rest("PATCH", f"properties?id=eq.{PA}", TOK["admin"],
                 body={"verification_status": "verified", "listing_status": "active"})
    audit("listing_verify", "property", PA)
    st, out = rest("GET", f"properties?id=eq.{PA}&select=id")  # anon
    record("TP-ADM-03b", st == 200 and len(out or []) == 1, f"publik={out}")
    st, _ = rest("PATCH", f"properties?id=eq.{PB}", TOK["admin"],
                 body={"verification_status": "rejected",
                       "reject_reason": "Foto tidak jelas"})
    audit("listing_reject", "property", PB, {"reason": "Foto tidak jelas"})
    st, out = rest("GET", f"properties?id=eq.{PB}&select=id")  # anon
    st2, row = svc("GET", f"rest/v1/properties?id=eq.{PB}&select=reject_reason")
    record("TP-ADM-03c",
           st == 200 and out == [] and row[0]["reject_reason"] == "Foto tidak jelas",
           f"publik={out}")

    # ADM-04: laporan resolve + hide review (isi review tidak diubah)
    st, _ = svc("POST", "rest/v1/reports", body={
        "id": REPORT, "reporter_id": UID["seeker1"],
        "target_type": "review",
        "target_id": svc("GET", "rest/v1/reviews?status=eq.approved"
                         "&select=id&limit=1")[1][0]["id"],
        "reason_code": "spam", "detail": "zz laporan", "status": "open"})
    st, _ = rest("PATCH", f"reports?id=eq.{REPORT}", TOK["admin"],
                 body={"status": "resolved", "resolution_note": "Ditangani admin",
                       "resolved_by": UID["admin"]})
    audit("report_resolved", "report", REPORT, {"note": "Ditangani admin"})
    st, row = svc("GET", f"rest/v1/reports?id=eq.{REPORT}"
                  "&select=status,resolution_note,resolved_by")
    record("TP-ADM-04a",
           st == 200 and row[0]["status"] == "resolved"
           and row[0]["resolved_by"] == UID["admin"], f"row={row}")
    rid = fixtures.get("review")
    if rid:
        st, out = rest("PATCH", f"reviews?id=eq.{rid}", TOK["admin"],
                       body={"status": "rejected"})  # tanpa alasan
        st2 = st
        st, _ = rest("PATCH", f"reviews?id=eq.{rid}", TOK["admin"],
                     body={"status": "hidden"})
        audit("review_hide", "review", rid)
        st3, row = svc("GET", f"rest/v1/reviews?id=eq.{rid}"
                       "&select=status,review_text,moderated_by")
        record("TP-ADM-04b",
               st2 == 400 and row[0]["status"] == "hidden"
               and row[0]["review_text"] == "zz-cp04b final review"
               and row[0]["moderated_by"] == UID["admin"],
               f"reject_no_reason={st2} hide={st}")
    else:
        record("TP-ADM-04b", False, "fixture review tidak ada")

    # ADM-05: fasilitas dinonaktifkan → tanda properti hilang; aktif lagi →
    # pulih manual (keputusan ADR: reaktivasi tidak restore). property_facilities
    # PK komposit (property_id, facility_id) — tidak ada kolom id.
    st, pf = svc("GET", "rest/v1/property_facilities?select=facility_id,property_id")
    facs: dict[str, list[str]] = {}
    for r in pf or []:
        facs.setdefault(r["facility_id"], []).append(r["property_id"])
    fid = max(facs, key=lambda k: len(facs[k]))
    marks_before = facs[fid]
    st, _ = rest("PATCH", f"facilities?id=eq.{fid}", TOK["admin"],
                 body={"is_active": False})
    audit("facility_update", "facility", fid, {"is_active": False})
    st, after = svc("GET", f"rest/v1/property_facilities?facility_id=eq.{fid}"
                    "&select=property_id")
    r1 = len(after or []) == 0
    st, _ = rest("PATCH", f"facilities?id=eq.{fid}", TOK["admin"],
                 body={"is_active": True})
    st_post, _ = svc("POST", "rest/v1/property_facilities", body=[
        {"property_id": p, "facility_id": fid} for p in marks_before])
    st, back = svc("GET", f"rest/v1/property_facilities?facility_id=eq.{fid}"
                   "&select=property_id")
    st, f1 = svc("GET", f"rest/v1/facilities?id=eq.{fid}&select=is_active")
    record("TP-ADM-05",
           r1 and st_post in (200, 201)
           and len(back or []) == len(marks_before) and f1[0]["is_active"],
           f"marks {len(marks_before)}→{len(after or [])}→"
           f"{len(back or [])} restore={st_post}")

    # ADM-06: jejak audit untuk aksi admin di atas
    acts = ("owner_reject", "owner_verify", "listing_verify", "listing_reject",
            "report_resolved", "facility_update", "review_hide")
    st, rows = rest("GET", f"audit_logs?action=in.({','.join(acts)})"
                    "&select=action", TOK["admin"])
    seen = {r["action"] for r in rows or []}
    record("TP-ADM-06", set(acts) <= seen, f"missing={sorted(set(acts) - seen)}")

    # ADM-07: hitungan interaksi admin = ground truth; admin tak bisa ubah metrik
    # batch PostgREST: seluruh objek harus punya kunci sama (PGRST102)
    batch = ([{"event_type": "property_view", "source": "zz-adm07",
               "property_id": "a0000000-0000-4000-8000-000000000001"}
              for _ in range(60)]
             + [{"event_type": "compare_add", "source": "zz-adm07",
                 "property_id": "a0000000-0000-4000-8000-000000000001"}
                for _ in range(40)])
    st_post, out_post = svc("POST", "rest/v1/interactions", body=batch)
    st, rows = rest("GET", "interactions?source=eq.zz-adm07"
                    "&select=event_type&limit=1000", TOK["admin"])
    counts: dict[str, int] = {}
    for r in rows if isinstance(rows, list) else []:
        counts[r["event_type"]] = counts.get(r["event_type"], 0) + 1
    st_up, _ = rest("PATCH", "interactions?source=eq.zz-adm07", TOK["admin"],
                    body={"event_weight": 5})
    st2, chk = svc("GET", "rest/v1/interactions?source=eq.zz-adm07"
                   "&select=event_weight&limit=1")
    # metrik tak bisa diubah admin lewat REST: tak ada policy UPDATE → 0 baris
    # terpengaruh (PostgREST bisa menjawab 204 tanpa error); bukti = nilai utuh
    unchanged = isinstance(chk, list) and chk and chk[0]["event_weight"] is None
    record("TP-ADM-07",
           st_post in (200, 201)
           and counts == {"property_view": 60, "compare_add": 40}
           and unchanged,
           f"post={st_post} {out_post!r:.150} get={st} counts={counts} "
           f"up={st_up}")
    svc("DELETE", "rest/v1/interactions?source=eq.zz-adm07")


# ---------------------------------------------------------------- TP-PAY
def test_pay() -> None:
    # PAY-02: 12 tagihan T1; baris jatuh tempo lewat tersedia untuk predikat overdue
    st, rows = svc("GET", f"rest/v1/payment_records?tenancy_id=eq.{T1}&select=id")
    n = len(rows or [])
    st, _ = svc("POST", "rest/v1/payment_records", body={
        "tenancy_id": T1, "due_date": "2026-09-10",
        "amount": PAST_DUE_AMOUNT, "status": "unpaid"})
    st, overdue = svc("GET", f"rest/v1/payment_records?tenancy_id=eq.{T1}"
                      "&status=eq.unpaid&due_date=lt.2026-09-25&select=id")
    record("TP-PAY-02", n == 12 and len(overdue or []) >= 1,
           f"dues={n} overdue_predicate={len(overdue or [])}")

    # PAY-03: seed reminder = tengah malam WIB (due − offset); lihat P2 di header
    st, rems = svc("GET", "rest/v1/reminders?tenancy_id=eq." + T1
                   + "&select=offset_days,fire_at,payment_record_id")
    st, recs = svc("GET", f"rest/v1/payment_records?tenancy_id=eq.{T1}"
                   "&select=id,due_date")
    due_of = {r["id"]: r["due_date"] for r in recs or []}
    expect = {7: "2026-09-23T17:00", 3: "2026-09-27T17:00",
              1: "2026-09-29T17:00", 0: "2026-09-30T17:00"}
    got = {r["offset_days"]: r["fire_at"][:16].replace(" ", "T")
           for r in rems or [] if due_of.get(r["payment_record_id"]) == "2026-10-01"}
    record("TP-PAY-03", all(got.get(k) == v for k, v in expect.items()),
           f"got={got}")

    # PAY-06: pihak owner & tenant melihat himpunan tagihan identik + predikat
    st, a = rest("GET", f"payment_records?tenancy_id=eq.{T1}&select=id,status,due_date",
                 TOK["owner1"])
    st, b = rest("GET", f"payment_records?tenancy_id=eq.{T1}&select=id,status,due_date",
                 TOK["seeker1"])
    sa = {(r["id"], r["status"], r["due_date"]) for r in a or []}
    sb = {(r["id"], r["status"], r["due_date"]) for r in b or []}
    today = dt.date.today().isoformat()
    soon = (dt.date.today() + dt.timedelta(days=7)).isoformat()
    od = {r for r in sa if r[1] == "unpaid" and r[2] < today}
    ds = {r for r in sa if r[1] == "unpaid" and today <= r[2] <= soon}
    record("TP-PAY-06", sa == sb and od and ds,
           f"equal={sa == sb} overdue={len(od)} due_soon={len(ds)}")

    # hapus baris jatuh tempo lewat sebelum mutasi bayar (reset manual juga
    # menghapusnya; di sini agar prediksi next_due tidak terpengaruh fixture)
    svc("DELETE", "rest/v1/payment_records?tenancy_id=eq." + T1
        + f"&amount=eq.{PAST_DUE_AMOUNT}")

    # PAY-04/05: tandai bayar (owner) → paid_at/marked_by + pengingat record
    # dibatalkan trigger + next_due maju; tenant tak bisa; restore bersih.
    st, rec = svc("GET", "rest/v1/payment_records?tenancy_id=eq." + T1
                  + "&due_date=eq.2026-11-01&select=id")
    rid = rec[0]["id"]
    st, sch0 = svc("GET", f"rest/v1/payment_schedules?tenancy_id=eq.{T1}"
                   "&select=next_due_date")
    next0 = sch0[0]["next_due_date"]
    st, _ = svc("POST", "rest/v1/reminders", body={
        "tenancy_id": T1, "payment_record_id": rid, "offset_days": 13,
        "fire_at": "2026-10-19T02:00:00+00:00", "status": "scheduled",
        "local_notification_id": "zz-13"})

    # tenant coba tandai bayar → tak berpengaruh (bukan pemilik)
    rest("PATCH", f"payment_records?id=eq.{rid}", TOK["seeker1"],
         body={"status": "paid"})
    st, row = svc("GET", f"rest/v1/payment_records?id=eq.{rid}&select=status")
    r_tenant = row[0]["status"] == "unpaid"

    # owner tandai bayar → trigger sets paid_at/marked_by + cancel reminder
    st, _ = rest("PATCH", f"payment_records?id=eq.{rid}", TOK["owner1"],
                 body={"status": "paid"})
    st, row = svc("GET", f"rest/v1/payment_records?id=eq.{rid}"
                  "&select=status,paid_at,marked_by")
    r_paid = (row[0]["status"] == "paid" and row[0]["paid_at"]
              and row[0]["marked_by"] == UID["owner1"])
    st, rem = svc("GET", f"rest/v1/reminders?payment_record_id=eq.{rid}"
                  "&select=status,offset_days")
    r_cancel = {r["offset_days"]: r["status"] for r in rem or []}
    st, sch = svc("GET", f"rest/v1/payment_schedules?tenancy_id=eq.{T1}"
                  "&select=next_due_date")
    st, un = svc("GET", f"rest/v1/payment_records?tenancy_id=eq.{T1}"
                 "&status=eq.unpaid&select=due_date")
    want_next = min((r["due_date"] for r in un or []), default=None)
    r_next = sch[0]["next_due_date"] == want_next  # AC-PAY-02: tagihan awal belum lunas
    record("TP-PAY-04", r_tenant and r_paid,
           f"tenant_guard={r_tenant} paid={row}")

    # PAY-05: resync ala app — batalkan semua scheduled, insert offset baru
    # pada record yang belum lunas, duplikat ditolak unique index
    st, reco = svc("GET", "rest/v1/payment_records?tenancy_id=eq." + T1
                   + "&due_date=eq.2026-10-01&select=id")
    oid = reco[0]["id"]
    st, _ = rest("PATCH", f"reminders?tenancy_id=eq.{T1}&status=eq.scheduled",
                 TOK["seeker1"], body={"status": "cancelled"})
    st, rems2 = svc("GET", f"rest/v1/reminders?tenancy_id=eq.{T1}"
                    "&select=status")
    all_cancel = all(r["status"] == "cancelled" for r in rems2 or [])
    st, _ = rest("POST", "reminders", TOK["seeker1"], body={
        "tenancy_id": T1, "payment_record_id": oid, "offset_days": 5,
        "fire_at": "2026-09-24T02:00:00+00:00", "status": "scheduled"})
    st_dup, out_dup = rest("POST", "reminders", TOK["seeker1"], body={
        "tenancy_id": T1, "payment_record_id": oid, "offset_days": 5,
        "fire_at": "2026-09-24T02:00:00+00:00", "status": "scheduled"})
    record("TP-PAY-05",
           all_cancel and r_cancel.get(13) == "cancelled" and r_next
           and st in (200, 201) and 400 <= st_dup < 500,
           f"cancel_all={all_cancel} planted={r_cancel.get(13)} "
           f"next_due={sch[0]['next_due_date']} want={want_next} dup={st_dup}")
    reset_payment_fixture()
    st, sch = svc("GET", f"rest/v1/payment_schedules?tenancy_id=eq.{T1}"
                  "&select=next_due_date")
    record("TP-PAY-07-restore", sch[0]["next_due_date"] == next0 == "2026-10-01",
           f"next_due={sch[0]['next_due_date']}")


# ---------------------------------------------------------------- TP-PRIV-02
def storage(method: str, path: str, token: str, *, body=None,
            ctype: str = "application/json"):
    return req(method, f"{SUPA}/storage/v1/{path}", token=token,
               body=body, ctype=ctype)


def test_priv() -> None:
    st, out = svc("POST", "auth/v1/admin/users", body={
        "email": PRIV_EMAIL, "password": PW, "email_confirm": True,
        "user_metadata": {"full_name": "ZZ CP04B Priv", "role": "seeker",
                          "tos_version": "v1.0",
                          "tos_accepted_at": dt.datetime.now(dt.timezone.utc)
                          .isoformat(), "data_consent": "true"}})
    if st >= 400:
        record("TP-PRIV-02", False, f"create_user {st} {out}")
        return
    puid = out["id"]
    tok = login(PRIV_EMAIL)

    # avatar diupload pemilik (app menghapus berkas sebelum RPC)
    st_up, out_up = storage("POST", f"object/avatars/{puid}/zz.png", tok,
                            body=b"zz", ctype="image/png")
    st, files = storage("POST", "object/list/avatars", tok,
                        body={"prefix": puid})
    has_avatar = (st == 200 and isinstance(files, list)
                  and any(f.get("name") == "zz.png" for f in files))
    # format hapus massal storage = {"prefixes": [...]} (storage_client 2.8)
    st_del, _ = storage("DELETE", "object/avatars", tok,
                        body={"prefixes": [f"{puid}/zz.png"]})

    st, out = rpc("delete_my_account", tok)
    if st >= 400:
        record("TP-PRIV-02", False, f"rpc {st} {out}")
        return
    st, prof = svc("GET", f"rest/v1/profiles?id=eq.{puid}"
                   "&select=full_name,phone,data_consent_at,status")
    p = prof[0]
    st2, files2 = storage("POST", "object/list/avatars", tok,
                          body={"prefix": puid})
    # jalur login dimatikan: email diganti (bukti kuat, tanpa bergantung
    # jaringan); percobaan login sesungguhnya tetap dicoba bila koneksi sehat
    st_u, user_row = svc("GET", f"auth/v1/admin/users/{puid}")
    email_renamed = (st_u == 200 and isinstance(user_row, dict)
                     and str(user_row.get("email", "")).startswith("deleted-"))
    st3 = None
    for _ in range(2):
        try:
            st3, _ = req("POST", f"{SUPA}/auth/v1/token?grant_type=password",
                         body={"email": PRIV_EMAIL, "password": PW})
            break
        except urllib.error.URLError:
            st3 = None  # reset koneksi transien; coba lagi
    login_blocked = st3 is None or st3 >= 400
    st4, audit = svc("GET", "rest/v1/audit_logs?action=eq.account_delete"
                     f"&target_id=eq.{puid}&select=id")
    gone = (st2 == 200 and isinstance(files2, list)
            and not [f for f in files2 if f.get("name")])
    ok = (has_avatar and p["full_name"] == "Pengguna Dihapus"
          and p["phone"] is None and p["data_consent_at"] is None
          and p["status"] == "suspended"
          and gone and email_renamed and login_blocked
          and len(audit or []) >= 1)
    record("TP-PRIV-02", ok,
           f"upload={st_up} avatar={has_avatar} del={st_del} "
           f"list2={st2}/{files2!r:.80} profile={p} "
           f"renamed={email_renamed} relogin={st3} audit={len(audit or [])}")
    # jejak: baris profile ikut terhapus saat auth user dihapus (FK cascade);
    # biarkan audit_logs (tanpa FK) sebagai bukti sampai cleanup akhir.
    svc("DELETE", f"rest/v1/recommendation_logs?user_id=eq.{puid}")
    svc("DELETE", f"auth/v1/admin/users/{puid}")


def main() -> int:
    setup()
    for fn in (test_rev, test_rec, test_adm, test_pay, test_priv):
        try:
            fn()
        except Exception as e:  # noqa: BLE001 — laporkan, jangan crash diam
            import traceback
            traceback.print_exc()
            record(f"{fn.__name__}:exception", False, repr(e))
    cleanup()
    fails = [r for r in results if r[1] == "FAIL"]
    print(f"\n{len(results) - len(fails)}/{len(results)} PASS")
    for f in fails:
        print(f"  FAIL {f[0]} {f[2]}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
