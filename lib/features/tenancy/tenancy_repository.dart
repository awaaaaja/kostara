import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/util/payment_schedule.dart';

/// Data tenancy seeker: ajukan/batal permintaan, tenancy aktif + jadwal bayar.
class TenancyRepository {
  TenancyRepository(this._db);

  final SupabaseClient _db;

  Future<void> submitRequest({
    required String propertyId,
    required String roomId,
    String? message,
  }) async {
    await _db.rpc(
      'submit_tenancy_request',
      params: {
        'p_property_id': propertyId,
        'p_room_id': roomId,
        if (message != null && message.trim().isNotEmpty)
          'p_message': message.trim(),
      },
    );
  }

  Future<void> cancelRequest(String requestId) async {
    await _db
        .from('tenancy_requests')
        .update({'status': 'cancelled'})
        .eq('id', requestId);
  }

  Future<List<Map<String, dynamic>>> myRequests() async {
    final rows = await _db
        .from('tenancy_requests')
        .select('''
          id, status, message, reject_reason, created_at, decided_at,
          property:properties(name),
          room:rooms(code)
        ''')
        .order('created_at', ascending: false);
    return rows;
  }

  /// Tenancy milik saya (aktif/riwayat) + jadwal pembayaran terdekat.
  Future<List<Map<String, dynamic>>> myTenancies() async {
    final rows = await _db
        .from('tenancies')
        .select('''
          id, status, start_date, end_date, amount, due_day, property_id,
          property:properties(name),
          room:rooms(code),
          payment_schedules(next_due_date, amount)
        ''')
        .order('start_date', ascending: false);
    return rows;
  }

  /// Tagihan terdekat (maks 3) untuk tenancy tertentu.
  Future<List<Map<String, dynamic>>> upcomingDues(String tenancyId) async {
    final rows = await _db
        .from('payment_records')
        .select('id, due_date, amount, status, paid_at')
        .eq('tenancy_id', tenancyId)
        .neq('status', 'paid')
        .order('due_date')
        .limit(3);
    return rows;
  }

  /// Riwayat pembayaran lengkap (untuk layar [Lihat riwayat], DESIGN §25).
  Future<List<Map<String, dynamic>>> paymentHistory(String tenancyId) async {
    final rows = await _db
        .from('payment_records')
        .select('id, due_date, amount, status, paid_at')
        .eq('tenancy_id', tenancyId)
        .order('due_date');
    return rows;
  }

  /// Offsets pengingat tersimpan di jadwal (kosong = mati, FR-NOT-01).
  Future<List<int>> reminderOffsets(String tenancyId) async {
    final rows = await _db
        .from('payment_schedules')
        .select('reminder_offsets')
        .eq('tenancy_id', tenancyId)
        .limit(1);
    if (rows.isEmpty) return const [];
    final raw = (rows.first['reminder_offsets'] as List?) ?? const [];
    return raw.map((e) => (e as num).toInt()).toList();
  }

  /// Simpan offsets (hanya field ini yang boleh diubah tenant —
  /// guard payment_schedules_guard, AC-PAY-03/FR-NOT-01).
  Future<void> saveReminderOffsets(String tenancyId, List<int> offsets) async {
    await _db
        .from('payment_schedules')
        .update({'reminder_offsets': offsets})
        .eq('tenancy_id', tenancyId);
  }

  /// Regenerasi baris `reminders` di server (AC-PAY-05): semua scheduled
  /// milik tenancy → cancelled, lalu insert baru per due terdekat × offsets —
  /// tanpa duplikat (unique index + insert berurutan). Mengembalikan job
  /// penjadwalan lokal: (dueDate, offset) untuk due terdekat (maks 2).
  Future<List<({DateTime dueDate, int offset, int amount})>> syncReminderRows(
    String tenancyId,
    List<int> offsets,
  ) async {
    if (offsets.isEmpty) {
      await _db
          .from('reminders')
          .update({'status': 'cancelled'})
          .eq('tenancy_id', tenancyId)
          .eq('status', 'scheduled');
      return const [];
    }
    final dues = await _db
        .from('payment_records')
        .select('id, due_date, amount')
        .eq('tenancy_id', tenancyId)
        .neq('status', 'paid')
        .order('due_date')
        .limit(2);

    // Batalkan yang lama lebih dulu → insert berikutnya bebas konflik
    // unique (payment_record_id, offset_days) WHERE scheduled.
    await _db
        .from('reminders')
        .update({'status': 'cancelled'})
        .eq('tenancy_id', tenancyId)
        .eq('status', 'scheduled');

    final jobs = <({DateTime dueDate, int offset, int amount})>[];
    final rows = <Map<String, dynamic>>[];
    for (final d in dues) {
      final dueDate = DateTime.parse('${d['due_date']}');
      final amount = (d['amount'] as num).toInt();
      for (final off in offsets) {
        final fireAt = DateTime.utc(
          dueDate.year,
          dueDate.month,
          dueDate.day,
          2,
        ).subtract(Duration(days: off));
        if (fireAt.isBefore(DateTime.now().toUtc())) continue; // sudah lewat
        rows.add({
          'tenancy_id': tenancyId,
          'payment_record_id': d['id'],
          'fire_at': fireAt.toIso8601String(),
          'offset_days': off,
          'status': 'scheduled',
          'local_notification_id':
              '${reminderNotificationId(tenancyId, dueDate, off)}',
        });
        jobs.add((dueDate: dueDate, offset: off, amount: amount));
      }
    }
    if (rows.isNotEmpty) {
      await _db.from('reminders').insert(rows);
    }
    return jobs;
  }

  /// Tagihan pada tenancy AKTIF milik saya — input [PaymentSummary]
  /// supaya angka home seeker identik dengan home owner (AC-PAY-06).
  Future<List<Map<String, dynamic>>> myOpenDues() async {
    final tenancies = await _db
        .from('tenancies')
        .select('id')
        .eq('status', 'active');
    final ids = tenancies.map((t) => t['id'] as String).toList();
    if (ids.isEmpty) return const [];
    final rows = await _db
        .from('payment_records')
        .select('id, due_date, amount, status, paid_at')
        .inFilter('tenancy_id', ids)
        .order('due_date');
    return rows;
  }
}

final tenancyRepositoryProvider = Provider<TenancyRepository>(
  (ref) => TenancyRepository(Supabase.instance.client),
);

final myTenancyRequestsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(tenancyRepositoryProvider).myRequests(),
);

final myTenanciesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(tenancyRepositoryProvider).myTenancies(),
);

/// Ringkasan pembayaran home seeker (AC-PAY-06) — [PaymentSummary] yang
/// sama dipakai dashboard owner sehingga angkanya identik per record.
final paymentSummaryProvider = FutureProvider<PaymentSummary>((ref) async {
  final rows = await ref.watch(tenancyRepositoryProvider).myOpenDues();
  return PaymentSummary.fromRows(rows, DateTime.now());
});

/// Pesan ramah untuk error RPC submit (needle cp03a §4).
String friendlyTenancyError(Object e) {
  final raw = e.toString();
  if (raw.contains('room_tidak_tersedia') ||
      raw.contains('room_sudah_terisi')) {
    return 'Kamar sudah tidak tersedia.';
  }
  if (raw.contains('masih_ada_permintaan_pending')) {
    return 'Kamu masih punya permintaan pending untuk kamar ini.';
  }
  if (raw.contains('property_sendiri')) {
    return 'Tidak bisa mengajukan sewa untuk kos milikmu sendiri.';
  }
  if (raw.contains('property_tidak_tersedia')) {
    return 'Kos tidak dapat diajukan saat ini.';
  }
  if (raw.contains('hanya_seeker')) {
    return 'Hanya pencari kos yang dapat mengajukan sewa.';
  }
  if (raw.contains('room_property_tidak_cocok')) {
    return 'Kamar tidak cocok dengan kos terpilih.';
  }
  return 'Gagal mengajukan sewa. Coba lagi.';
}
