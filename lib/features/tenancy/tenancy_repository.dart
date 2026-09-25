import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          id, status, start_date, end_date, amount, due_day,
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
