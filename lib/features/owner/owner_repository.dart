import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/util/payment_schedule.dart';

/// Akses data owner: dashboard, properti/kamar, permintaan, pembayaran,
/// verifikasi dokumen. Semua dibatasi RLS `fn_owns_property`/`fn_is_tenancy_owner`.
class OwnerRepository {
  OwnerRepository(this._db);

  final SupabaseClient _db;

  String get _uid => _db.auth.currentUser!.id;

  Future<Map<String, int>> dashboard() async {
    final props = await _db
        .from('properties')
        .select('id, listing_status')
        .eq('owner_id', _uid);
    final pending = await _db
        .from('tenancy_requests')
        .select('id')
        .eq('status', 'pending');
    final dues = await _db
        .from('payment_records')
        .select('id, due_date, amount, status');
    // Helper yang sama dengan home seeker (AC-PAY-06) → angka identik.
    final summary = PaymentSummary.fromRows(dues, DateTime.now());
    return {
      'properties_total': props.length,
      'properties_active': props
          .where((p) => p['listing_status'] == 'active')
          .length,
      'requests_pending': pending.length,
      'payments_unpaid': summary.unpaidCount,
      'payments_overdue': summary.overdueCount,
    };
  }

  /// Insight feedback (DESIGN §31): rata-rata skor aspek dari review
  /// approved di properti milik owner. `null` bila < 3 review — klaim
  /// tanpa minimum evidence dilarang (DESIGN §31).
  Future<FeedbackInsight?> feedbackInsight() async {
    final props = await _db
        .from('properties')
        .select('id')
        .eq('owner_id', _uid);
    if (props.isEmpty) return null;
    final ids = props.map((p) => '${p['id']}').toList();
    final reviews = await _db
        .from('reviews')
        .select('id')
        .eq('status', 'approved')
        .inFilter('property_id', ids);
    if (reviews.length < 3) return null;
    final scores = await _db
        .from('review_aspect_scores')
        .select('aspect, score')
        .inFilter('review_id', reviews.map((r) => '${r['id']}').toList())
        .eq('source', 'manual');
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final s in scores) {
      final score = (s['score'] as num?)?.toDouble();
      if (score == null) continue;
      final aspect = '${s['aspect']}';
      sums[aspect] = (sums[aspect] ?? 0) + score;
      counts[aspect] = (counts[aspect] ?? 0) + 1;
    }
    final avgs = [
      for (final e in sums.entries) (e.key, e.value / counts[e.key]!),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    if (avgs.isEmpty) return null;
    return FeedbackInsight(reviewCount: reviews.length, aspects: avgs);
  }

  Future<List<Map<String, dynamic>>> myProperties() async {
    final rows = await _db
        .from('properties')
        .select('''
          id, name, address, gender_policy, description, rules,
          listing_status, verification_status,
          rooms(id, status),
          property_images(storage_path, is_cover, sort_order)
        ''')
        .eq('owner_id', _uid)
        .order('created_at', ascending: false);
    return rows;
  }

  Future<void> updateProperty(
    String id, {
    required Map<String, dynamic> fields,
  }) async {
    await _db.from('properties').update(fields).eq('id', id);
  }

  /// Unggah foto ke bucket `property-images` (path `<property_id>/…`,
  /// FR-OWN-02). Sampai jadi cover bila property belum punya cover.
  Future<void> uploadPropertyPhotos(
    String propertyId,
    List<String> localPaths,
  ) async {
    if (localPaths.isEmpty) return;
    final existing = await _db
        .from('property_images')
        .select('id, is_cover')
        .eq('property_id', propertyId);
    var order = existing.length;
    var hasCover = existing.any((r) => r['is_cover'] == true);
    for (final local in localPaths) {
      final bytes = await File(local).readAsBytes();
      final lower = local.toLowerCase();
      final ext = lower.endsWith('.png')
          ? 'png'
          : lower.endsWith('.webp')
          ? 'webp'
          : 'jpg';
      final path =
          '$propertyId/foto-${DateTime.now().millisecondsSinceEpoch}'
          '-$order.$ext';
      await _db.storage
          .from('property-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: ext == 'jpg' ? 'image/jpeg' : 'image/$ext',
              upsert: false,
            ),
          );
      await _db.from('property_images').insert({
        'property_id': propertyId,
        'storage_path': path,
        'is_cover': !hasCover,
        'sort_order': order,
      });
      hasCover = true;
      order++;
    }
  }

  Future<void> deletePropertyPhoto(
    String propertyId,
    String storagePath,
  ) async {
    await _db.storage.from('property-images').remove([storagePath]);
    await _db
        .from('property_images')
        .delete()
        .eq('property_id', propertyId)
        .eq('storage_path', storagePath);
  }

  Future<List<Map<String, dynamic>>> propertyRooms(String propertyId) async {
    final rows = await _db
        .from('rooms')
        .select('id, code, room_type, price, deposit, status, size_sqm')
        .eq('property_id', propertyId)
        .order('code');
    return rows;
  }

  Future<void> addRoom(
    String propertyId, {
    required String code,
    required String roomType,
    required int price,
    int deposit = 0,
  }) async {
    await _db.from('rooms').insert({
      'property_id': propertyId,
      'code': code,
      'room_type': roomType,
      'price': price,
      'deposit': deposit,
    });
  }

  Future<void> updateRoom(String id, Map<String, dynamic> fields) async {
    await _db.from('rooms').update(fields).eq('id', id);
  }

  Future<void> deleteRoom(String id) async {
    await _db.from('rooms').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> pendingRequests() async {
    final rows = await _db
        .from('tenancy_requests')
        .select('''
          id, status, message, created_at,
          property:properties(name),
          room:rooms(code),
          seeker:profiles!seeker_id(full_name)
        ''')
        .eq('status', 'pending')
        .order('created_at');
    return rows;
  }

  Future<void> acceptRequest(String requestId) async {
    await _db.rpc('activate_tenancy', params: {'p_request_id': requestId});
  }

  Future<void> rejectRequest(String requestId, String reason) async {
    await _db
        .from('tenancy_requests')
        .update({
          'status': 'rejected',
          'reject_reason': reason.trim(),
          'decided_at': DateTime.now().toUtc().toIso8601String(),
          'decided_by': _uid,
        })
        .eq('id', requestId);
  }

  Future<List<Map<String, dynamic>>> activeTenants() async {
    final rows = await _db
        .from('tenancies')
        .select('''
          id, status, start_date, amount, due_day,
          property:properties(name),
          room:rooms(code),
          seeker:profiles!seeker_id(full_name),
          payment_schedules(next_due_date)
        ''')
        .eq('status', 'active')
        .order('start_date', ascending: false);
    return rows;
  }

  Future<List<Map<String, dynamic>>> duePayments() async {
    final rows = await _db
        .from('payment_records')
        .select('''
          id, due_date, amount, status, paid_at,
          tenancy:tenancies!inner(
            id, property:properties(name), room:rooms(code),
            seeker:profiles!seeker_id(full_name)
          )
        ''')
        .order('due_date');
    return rows;
  }

  Future<void> markPaid(String paymentId) async {
    await _db
        .from('payment_records')
        .update({'status': 'paid'})
        .eq('id', paymentId);
  }

  Future<Map<String, dynamic>?> myVerification() async {
    return _db
        .from('owner_profiles')
        .select(
          'user_id, verification_status, doc_path, submitted_at, reject_reason',
        )
        .eq('user_id', _uid)
        .maybeSingle();
  }

  /// Upload hasil (path sudah diunggah ke bucket privat) + ajukan/ajukan ulang.
  Future<void> submitVerification(String docPath) async {
    final existing = await myVerification();
    if (existing == null) {
      await _db.from('owner_profiles').insert({
        'user_id': _uid,
        'verification_status': 'pending',
        'doc_path': docPath,
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
      });
    } else {
      await _db
          .from('owner_profiles')
          .update({
            'doc_path': docPath,
            'submitted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', _uid);
    }
  }
}

final ownerRepositoryProvider = Provider<OwnerRepository>(
  (ref) => OwnerRepository(Supabase.instance.client),
);

/// Rata-rata skor aspek per key, terurut desc; `null` = sample terlalu kecil.
class FeedbackInsight {
  const FeedbackInsight({required this.reviewCount, required this.aspects});

  final int reviewCount;
  final List<(String, double)> aspects;
}

final ownerFeedbackInsightProvider = FutureProvider<FeedbackInsight?>(
  (ref) => ref.watch(ownerRepositoryProvider).feedbackInsight(),
);

final ownerDashboardProvider = FutureProvider<Map<String, int>>(
  (ref) => ref.watch(ownerRepositoryProvider).dashboard(),
);

final ownerPropertiesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(ownerRepositoryProvider).myProperties(),
);

final ownerPropertyRoomsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
      (ref, propertyId) =>
          ref.watch(ownerRepositoryProvider).propertyRooms(propertyId),
    );

final ownerPendingRequestsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(ownerRepositoryProvider).pendingRequests(),
);

final ownerActiveTenantsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(ownerRepositoryProvider).activeTenants(),
);

final ownerDuePaymentsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(ownerRepositoryProvider).duePayments(),
);

final ownerVerificationProvider = FutureProvider<Map<String, dynamic>?>(
  (ref) => ref.watch(ownerRepositoryProvider).myVerification(),
);
