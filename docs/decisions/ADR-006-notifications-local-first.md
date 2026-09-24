# ADR-006 — Notifications: local scheduled V1; server push ditunda (P1)

Status: Accepted (V1) · Push = Deferred P1
Date: 2026-09-25

## Context
FR-PAY-03/FR-NOT-01: reminder 7/3/1/0 hari + custom via **local scheduled
notification**, timezone Asia/Jakarta, regenerasi saat schedule berubah
(AC-PAY-03/05). PRD §20 mengizinkan opsi lokal maupun server. CP-02 scope lock
menaruh push + `notification_outbox` di P1.

## Options
1. **Local scheduled (flutter_local_notifications + timezone) — jadwal dibuat
   device dari `payment_schedules`.**
2. Server push (FCM) sekarang + outbox table + token registry.
3. Hybrid lokal + outbox sejak V1.

## Decision
Opsi 1 untuk V1:
- Jadwal dibuat/diulang (cancel+reschedule) saat: tenancy aktif, due date
  berubah, offsets berubah, perangkat ganti (re-sync saat app dibuka).
- `reminders` table tetap jadi catatan status (scheduled/fired/cancelled);
  `local_notification_id` untuk anti-duplikat (unique partial).
- Limitasi jujur ditampilkan di UI reminder: notifikasi lokal butuh device
  menerima jadwal; tidak lintas perangkat.
- Push/FCM + `notification_outbox` = P1 setelah V1 PASS (kontrak ditulis saat
  di-authorized); tidak ada kode/kolom push yang dibuat "untuk jaga-jaga".

## Consequences
- (+) tanpa dependency FCM/kredensial server; alur teruji offline; regenerasi
  sederhana; scope sesuai 16 minggu.
- (−) tidak ada reminder saat app tidak pernah dibuka lagi sebelum jatuh tempo —
  dikomunikasikan (R-020); owner side tetap melihat due-soon di dashboard.
- Keputusan ini menutup kebutuhan Edge Function di V1 (lihat ADR-004).

## Validation
- TP-PAY-01..05 (due date termasuk kabisat 31→28/29, offset tepat hari,
  regenerasi tanpa duplikat); review UX memastikan copy limitasi tampil.
