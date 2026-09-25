#!/usr/bin/env python3
"""CP-03B DB test harness: TP-DB constraints, TP-GIS spatial, TP-RLS enable.
Jalankan: python3 scripts/run_db_tests.py  (exit 1 bila ada FAIL)"""

from __future__ import annotations

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import run_sql  # noqa: E402

P1 = "a0000000-0000-4000-8000-000000000001"  # property owner1 (verified, active)
P6 = "a0000000-0000-4000-8000-000000000006"  # property owner2 (verified, active)
P11 = "a0000000-0000-4000-8000-000000000011"  # draft milik owner1
T1 = "e0000000-0000-4000-8000-000000000001"  # active milik seeker1, property P1
T4 = "e0000000-0000-4000-8000-000000000004"  # ended milik seeker1, property a…007
T3 = "e0000000-0000-4000-8000-000000000003"  # ended milik seeker3, property a…005, final review ada
RV4 = "d0000000-0000-4000-8000-000000000004"  # review pulse milik seeker1 (pending)
P5 = "a0000000-0000-4000-8000-000000000005"
U11 = "00000000-0000-4000-8000-000000000011"  # uuid inert untuk tes FK/check
BUSINESS_TABLES = [
    "profiles", "owner_profiles", "campuses", "facilities", "properties",
    "property_images", "rooms", "property_facilities", "user_preferences",
    "favorites", "interactions", "tenancy_requests", "tenancies",
    "payment_schedules", "payment_records", "reminders", "model_versions",
    "model_params", "reviews", "review_aspect_scores", "reports",
    "recommendation_logs", "audit_logs",
]

results: list[tuple[str, str, str]] = []


def record(tid: str, ok: bool, detail: str = "") -> None:
    results.append((tid, "PASS" if ok else "FAIL", detail))
    print(f"  {tid}: {'PASS' if ok else 'FAIL'} {detail}")


def expect_error(tid: str, sql: str, *needles: str) -> None:
    """PASS bila query error dan semua needle ada di pesan error (casefold)."""
    try:
        run_sql.run(sql)
    except SystemExit as e:
        msg = str(e).lower()
        missing = [n for n in needles if n.lower() not in msg]
        record(tid, not missing, "" if not missing else f"missing {missing}: {str(e)[:200]}")
        return
    record(tid, False, "expected error, query succeeded")


def scalar(sql: str):
    return next(iter(run_sql.run(sql)[0].values()))


def one_row(sql: str) -> dict:
    return run_sql.run(sql)[0]


print("== TP-DB constraints ==")
expect_error(
    "TP-DB-01 harga kamar negatif",
    f"""insert into public.rooms (id, property_id, code, room_type, price)
    values ('11111111-0000-4000-8000-000000000001', '{P1}', 'NEG-1', 'standard', -5000)""",
    "violates check constraint", "price",
)
expect_error(
    "TP-DB-02 budget_max < budget_min",
    f"""insert into public.user_preferences (user_id, budget_min, budget_max)
    values ('{U11}', 2000000, 1000000)""",
    "violates check constraint", "user_preferences_check",
)
expect_error(
    "TP-DB-03 rating > 5",
    f"""insert into public.reviews (id, tenancy_id, property_id, user_id,
       review_type, rating_overall, review_text, status)
    values ('11111111-0000-4000-8000-000000000001', '{T4}', '{P1}', '{U11}',
       'final', 6, 'bad', 'pending')""",
    "violates check constraint", "rating_overall",
)
expect_error(
    "TP-DB-04 duplikat kode kamar per property",
    f"""insert into public.rooms (id, property_id, code, room_type, price)
    values ('11111111-0000-4000-8000-000000000002', '{P1}', 'R1', 'single', 900000)""",
    "duplicate key", "rooms_property_id_code_key",
)
expect_error(
    "TP-DB-05 active tanpa verified",
    f"update public.properties set listing_status = 'active' where id = '{P11}'",
    "properties_guard",
)
expect_error(
    "TP-DB-06 transisi kamar available→occupied tidak valid",
    f"update public.rooms set status = 'occupied' where property_id = '{P1}' and code = 'R2'",
    "rooms_guard:transisi_tidak_valid",
)
expect_error(
    "TP-DB-07 review property != tenancy property",
    f"""insert into public.reviews (id, tenancy_id, property_id, user_id,
       review_type, rating_overall, review_text, status)
    values ('11111111-0000-4000-8000-000000000003', '{T4}', '{P6}', '{U11}',
       'pulse', 4, 'mismatch', 'pending')""",
    "violates foreign key constraint",
)
expect_error(
    "TP-DB-08 tenancy_request room/property mismatch",
    f"""insert into public.tenancy_requests (id, property_id, room_id, seeker_id, status, message)
    values ('11111111-0000-4000-8000-000000000004', '{P6}',
            (select room_id from public.tenancies where id = '{T1}'),
            '{U11}', 'pending', 'tes')""",
    "tenancy_requests_guard",
)
expect_error(
    "TP-DB-09 dua tenancy aktif satu kamar",
    f"""insert into public.tenancies (id, property_id, room_id, seeker_id, owner_id,
       start_date, amount, due_day, status)
    select '11111111-0000-4000-8000-000000000005', t.property_id, t.room_id,
           '{U11}', t.owner_id, '2026-11-01', 1000000, 1, 'active'
    from public.tenancies t where t.id = '{T1}'""",
    "duplicate key", "tenancies_one_active_per_room",
)
expect_error(
    "TP-DB-10 review duplikat (tenancy, type)",
    f"""insert into public.reviews (id, tenancy_id, property_id, user_id,
       review_type, rating_overall, review_text, status)
    values ('11111111-0000-4000-8000-000000000006', '{T3}', '{P5}', '{U11}',
       'final', 5, 'dup', 'pending')""",
    "duplicate key", "reviews_tenancy_id_review_type_key",
)
expect_error(
    "TP-DB-11 payment_record duplikat (tenancy, due)",
    f"""insert into public.payment_records (id, tenancy_id, due_date, amount, status)
    values ('11111111-0000-4000-8000-000000000007', '{T1}', '2026-08-01', 1250000, 'unpaid')""",
    "duplicate key", "payment_records_tenancy_id_due_date_key",
)
expect_error(
    "TP-DB-12 reminder terjadwal duplikat (record, offset)",
    f"""insert into public.reminders (id, tenancy_id, payment_record_id, fire_at, offset_days, status)
    select '11111111-0000-4000-8000-000000000008', rm.tenancy_id, rm.payment_record_id,
           rm.fire_at, rm.offset_days, 'scheduled'
    from public.reminders rm
    where rm.payment_record_id is not null and rm.status = 'scheduled'
    limit 1""",
    "duplicate key", "reminders_scheduled_uq",
)
expect_error(
    "TP-DB-13 edit konten review ditolak",
    f"update public.reviews set review_text = 'edited' where id = '{RV4}'",
    "reviews_guard",
)
expect_error(
    "TP-DB-14 event_type di luar taxonomy",
    f"""insert into public.interactions (user_id, property_id, event_type, source, occurred_at)
    values ('{U11}', '{P1}', 'clickbait', 'app', now())""",
    "violates check constraint", "event_type",
)

print("== TP-GIS spatial ==")
r = one_row(
    f"""select
         st_distance(p.location, c.location)::numeric as d_geo,
         (6371000 * 2 * asin(sqrt(
            power(sin(radians(st_y(c.location::geometry) - st_y(p.location::geometry)) / 2), 2) +
            cos(radians(st_y(p.location::geometry))) * cos(radians(st_y(c.location::geometry))) *
            power(sin(radians(st_x(c.location::geometry) - st_x(p.location::geometry)) / 2), 2)
         )))::numeric as d_hav
       from public.properties p, public.campuses c
       where p.id = '{P1}' and c.name ilike '%Unand%'"""
)
geo, hav = float(r["d_geo"]), float(r["d_hav"])
record("TP-GIS-01 haversine vs st_distance", abs(geo - hav) / hav < 0.005,
       f"geo={geo:.1f} hav={hav:.1f} diff={abs(geo - hav) / hav:.5f}")

r = one_row(
    """select st_y(c.location::geometry) as lat, st_x(c.location::geometry) as lng
       from public.campuses c where c.name ilike '%Unand%'"""
)
lat, lng = float(r["lat"]), float(r["lng"])
direct = scalar(
    """select count(*)::int from public.properties p, public.campuses c
       where c.name ilike '%Unand%'
         and st_dwithin(p.location, c.location, 2500)
         and p.verification_status = 'verified' and p.listing_status = 'active'"""
)
items = run_sql.run(
    f"select nearby_properties({lat}::double precision, {lng}::double precision, 2500, '{{}}'::jsonb, 1, 20)"
)[0]
items = items["nearby_properties"]["items"]
maxd = max((i.get("distance_m", -1) for i in items), default=-1)
record("TP-GIS-02 near radius 2500m", int(direct) == len(items) and maxd <= 2500.5,
       f"direct={direct} rpc={len(items)} max_dist={maxd}")

direct_bbox = scalar(
    f"""select count(*)::int from public.properties
        where location && st_makeenvelope({lng - 0.01}, {lat - 0.01}, {lng + 0.01}, {lat + 0.01}, 4326)::geography
          and verification_status = 'verified' and listing_status = 'active'"""
)
bbox = run_sql.run(
    f"select search_properties(p_bbox := array[{lng - 0.01}, {lat - 0.01}, {lng + 0.01}, {lat + 0.01}])"
)[0]["search_properties"]["items"]
record("TP-GIS-03 bbox count == brute force", int(direct_bbox) == len(bbox),
       f"direct={direct_bbox} rpc={len(bbox)}")

plan = run_sql.run(
    "set enable_seqscan=off; explain (format text) select id from public.properties "
    f"where location && st_makeenvelope({lng}, {lat}, {lng + 0.01}, {lat + 0.01}, 4326)::geography"
)
plan_text = " ".join(" ".join(str(v) for v in row.values()) for row in plan)
record("TP-GIS-04 GIST index scan", "properties_location_gist" in plan_text and "Index Scan" in plan_text,
       plan_text[:150])

r = run_sql.run(
    """select
      (select coalesce(jsonb_agg(elem ->> 'id'), '[]'::jsonb)
         from jsonb_array_elements((search_properties(p_page := 1, p_page_size := 5) -> 'items')) as _a(elem)) as p1,
      (select coalesce(jsonb_agg(elem ->> 'id'), '[]'::jsonb)
         from jsonb_array_elements((search_properties(p_page := 2, p_page_size := 5) -> 'items')) as _b(elem)) as p2,
      (select coalesce(jsonb_agg(elem ->> 'id'), '[]'::jsonb)
         from jsonb_array_elements((search_properties(p_page_size := 20) -> 'items')) as _c(elem)) as full_ids"""
)[0]
p1, p2, full = r["p1"], r["p2"], r["full_ids"]
overlap = set(p1) & set(p2)
record("TP-GIS-05 pagination deterministik",
       len(p1) == 5 and len(p2) == 5 and not overlap and set(p1) | set(p2) <= set(full),
       f"|p1|={len(p1)} |p2|={len(p2)} overlap={len(overlap)}")

n_cols = scalar(
    """select count(*)::int from information_schema.columns
       where table_schema = 'public'
         and lower(column_name) in ('lat','lng','latitude','longitude','user_lat','last_lat','coord','coordinates')"""
)
record("TP-PRIV-01 tidak ada kolom koordinat pengguna", int(n_cols) == 0, f"cols={n_cols}")

r = run_sql.run(
    """select (select count(*)::int from public.interactions) as i1,
              (select count(*)::int from public.recommendation_logs) as l1"""
)[0]
run_sql.run(f"select nearby_properties({lat}::double precision, {lng}::double precision, 20000)")
run_sql.run("select feed_recommendations(5)")
r2 = run_sql.run(
    """select (select count(*)::int from public.interactions) as i2,
              (select count(*)::int from public.recommendation_logs) as l2"""
)[0]
record("TP-PRIV-02 panggilan GPS/feed tidak meninggalkan jejak (uid null)",
       r["i1"] == r2["i2"] and r["l1"] == r2["l2"],
       f"interactions {r['i1']}->{r2['i2']}, logs {r['l1']}->{r2['l2']}")

print("== TP-RLS enable ==")
r = one_row(
    f"""select
      (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relname = any (array[{','.join(repr(t) for t in BUSINESS_TABLES)}])
          and c.relrowsecurity) as enabled,
      (select count(*)::int from pg_tables t
        where t.schemaname = 'public' and t.tablename = any (array[{','.join(repr(t) for t in BUSINESS_TABLES)}])
          and not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = t.tablename)) as no_policy"""
)
record("TP-RLS-08 23 tabel RLS aktif + ada policy",
       r["enabled"] == 23 and r["no_policy"] == 0,
       f"rls={r['enabled']}/23 no_policy={r['no_policy']}")

fails = [x for x in results if x[1] == "FAIL"]
print(f"\n== SUMMARY: {len(results) - len(fails)}/{len(results)} PASS ==")
for tid, st, det in fails:
    print(f"  FAIL {tid}: {det}")
sys.exit(1 if fails else 0)
