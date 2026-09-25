import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/util/ewkb.dart';

/// Ringkasan platform (FR-ADM-01, AC-ADM-01) — semua angka = count query
/// ground truth; antrian moderasi = baris dengan status tertentu.
class AdminOverview {
  const AdminOverview({
    required this.users,
    required this.properties,
    required this.rooms,
    required this.tenancies,
    required this.reviews,
    required this.reports,
    required this.ownerPending,
    required this.listingPending,
    required this.reportsOpen,
    required this.reviewsPending,
  });

  final int users;
  final int properties;
  final int rooms;
  final int tenancies;
  final int reviews;
  final int reports;
  final int ownerPending;
  final int listingPending;
  final int reportsOpen;
  final int reviewsPending;

  Map<String, int> get queues => {
    'owner_pending': ownerPending,
    'listing_pending': listingPending,
    'reports_open': reportsOpen,
    'reviews_pending': reviewsPending,
  };
}

/// Aksi privileged super admin (FR-ADM-01..05). Semua lolos RLS
/// `app_is_admin()`; setiap aksi menulis `audit_log_write` (AC-ADM-06).
class AdminRepository {
  AdminRepository(this._db);

  final SupabaseClient _db;

  String get _uid => _db.auth.currentUser!.id;

  Future<void> _audit(
    String action, {
    String? targetType,
    String? targetId,
    Map<String, dynamic>? detail,
  }) async {
    await _db.rpc(
      'audit_log_write',
      params: {
        'p_action': action,
        'p_target_type': ?targetType,
        'p_target_id': ?targetId,
        'p_detail': ?detail,
      },
    );
  }

  // ===== FR-ADM-01: platform overview =====

  Future<AdminOverview> overview() async {
    final users = await _db.from('profiles').count();
    final properties = await _db.from('properties').count();
    final rooms = await _db.from('rooms').count();
    final tenancies = await _db.from('tenancies').count();
    final reviews = await _db.from('reviews').count();
    final reports = await _db.from('reports').count();
    final ownerPending = await _db
        .from('owner_profiles')
        .count()
        .eq('verification_status', 'pending');
    final listingPending = await _db
        .from('properties')
        .count()
        .eq('verification_status', 'pending');
    final reportsOpen = await _db.from('reports').count().eq('status', 'open');
    final reviewsPending = await _db
        .from('reviews')
        .count()
        .eq('status', 'pending');
    return AdminOverview(
      users: users,
      properties: properties,
      rooms: rooms,
      tenancies: tenancies,
      reviews: reviews,
      reports: reports,
      ownerPending: ownerPending,
      listingPending: listingPending,
      reportsOpen: reportsOpen,
      reviewsPending: reviewsPending,
    );
  }

  // ===== FR-ADM-02: verifikasi owner =====

  Future<List<Map<String, dynamic>>> pendingOwners() async {
    final rows = await _db
        .from('owner_profiles')
        .select('''
          user_id, doc_path, submitted_at,
          profile:profiles!user_id(full_name, phone, status)
        ''')
        .eq('verification_status', 'pending')
        .order('submitted_at', ascending: true);
    return rows;
  }

  Future<void> approveOwner(String userId) async {
    await _db
        .from('owner_profiles')
        .update({
          'verification_status': 'verified',
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          'reviewer_id': _uid,
          'reject_reason': null,
        })
        .eq('user_id', userId);
    await _audit('owner_verify', targetType: 'owner', targetId: userId);
  }

  Future<void> rejectOwner(String userId, String reason) async {
    await _db
        .from('owner_profiles')
        .update({
          'verification_status': 'rejected',
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          'reviewer_id': _uid,
          'reject_reason': reason,
        })
        .eq('user_id', userId);
    await _audit(
      'owner_reject',
      targetType: 'owner',
      targetId: userId,
      detail: {'reason': reason},
    );
  }

  // ===== FR-ADM-02: verifikasi listing =====

  Future<List<Map<String, dynamic>>> pendingListings() async {
    final rows = await _db
        .from('properties')
        .select('''
          id, name, address, listing_status, reject_reason, created_at,
          owner:profiles!owner_id(full_name, phone),
          property_images(storage_path, is_cover, sort_order)
        ''')
        .eq('verification_status', 'pending')
        .order('created_at', ascending: true);
    return rows;
  }

  /// Approve: verified + listing langsung aktif bila masih draft
  /// (AC-ADM-03: approve → tampil publik).
  Future<void> approveListing(String id, {required bool wasDraft}) async {
    await _db
        .from('properties')
        .update({
          'verification_status': 'verified',
          'reject_reason': null,
          if (wasDraft) 'listing_status': 'active',
        })
        .eq('id', id);
    await _audit('listing_verify', targetType: 'property', targetId: id);
  }

  Future<void> rejectListing(String id, String reason) async {
    await _db
        .from('properties')
        .update({'verification_status': 'rejected', 'reject_reason': reason})
        .eq('id', id);
    await _audit(
      'listing_reject',
      targetType: 'property',
      targetId: id,
      detail: {'reason': reason},
    );
  }

  Future<String> signedDocUrl(String path, {int seconds = 300}) async {
    final url = await _db.storage
        .from('verification-documents-private')
        .createSignedUrl(path, seconds);
    return url;
  }

  // ===== FR-ADM-03: moderasi report & review =====

  Future<List<Map<String, dynamic>>> openReports() async {
    final rows = await _db
        .from('reports')
        .select('''
          id, target_type, target_id, reason_code, detail, status,
          created_at, reporter:profiles!reporter_id(full_name)
        ''')
        .eq('status', 'open')
        .order('created_at', ascending: true);
    return rows;
  }

  Future<void> resolveReport(
    String id, {
    required String status, // resolved | rejected
    String? note,
  }) async {
    await _db
        .from('reports')
        .update({
          'status': status,
          'resolved_by': _uid,
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
          if (note != null && note.trim().isNotEmpty) 'resolution_note': note,
        })
        .eq('id', id);
    await _audit(
      'report_$status',
      targetType: 'report',
      targetId: id,
      detail: (note != null && note.isNotEmpty) ? {'note': note} : null,
    );
  }

  Future<List<Map<String, dynamic>>> pendingReviews() async {
    final rows = await _db
        .from('reviews')
        .select('''
          id, rating_overall, review_text, status, created_at,
          property:properties!property_id(name),
          user:profiles!user_id(full_name),
          review_aspect_scores(aspect, score, sentiment)
        ''')
        .eq('status', 'pending')
        .order('created_at', ascending: true)
        .limit(50);
    return rows;
  }

  Future<List<Map<String, dynamic>>> visibleReviews() async {
    final rows = await _db
        .from('reviews')
        .select('''
          id, rating_overall, review_text, status, created_at,
          property:properties!property_id(name)
        ''')
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .limit(20);
    return rows;
  }

  /// Moderasi review: approve / reject (alasan wajib, dicek guard) /
  /// hide (flag saja, isi asli tetap utuh — AC-ADM-04).
  Future<void> moderateReview(
    String id, {
    required String action, // approve | reject | hide
    String? reason,
  }) async {
    final status = switch (action) {
      'approve' => 'approved',
      'reject' => 'rejected',
      _ => 'hidden',
    };
    await _db
        .from('reviews')
        .update({
          'status': status,
          'moderated_by': _uid,
          if (reason != null && reason.trim().isNotEmpty)
            'moderation_reason': reason,
        })
        .eq('id', id);
    await _audit(
      'review_$action',
      targetType: 'review',
      targetId: id,
      detail: (reason != null && reason.isNotEmpty) ? {'reason': reason} : null,
    );
  }

  // ===== FR-ADM-04: master facilities & campuses =====

  Future<List<Map<String, dynamic>>> facilities() async {
    final rows = await _db
        .from('facilities')
        .select('id, slug, name, category, is_active')
        .order('name');
    return rows;
  }

  Future<void> setFacilityActive(String id, bool active) async {
    await _db.from('facilities').update({'is_active': active}).eq('id', id);
    await _audit(
      'facility_update',
      targetType: 'facility',
      targetId: id,
      detail: {'is_active': active},
    );
  }

  Future<void> createFacility({
    required String slug,
    required String name,
    String? category,
  }) async {
    await _db.from('facilities').insert({
      'slug': slug,
      'name': name,
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
    });
    await _audit(
      'facility_create',
      targetType: 'facility',
      detail: {'slug': slug},
    );
  }

  Future<List<Map<String, dynamic>>> campuses() async {
    final rows = await _db
        .from('campuses')
        .select('id, name, address, is_active')
        .order('name');
    return rows;
  }

  Future<void> setCampusActive(String id, bool active) async {
    await _db.from('campuses').update({'is_active': active}).eq('id', id);
    await _audit(
      'campus_update',
      targetType: 'campus',
      targetId: id,
      detail: {'is_active': active},
    );
  }

  Future<void> createCampus({
    required String name,
    String? address,
    required double lat,
    required double lng,
  }) async {
    await _db.from('campuses').insert({
      'name': name,
      if (address != null && address.trim().isNotEmpty)
        'address': address.trim(),
      'location': latLngToEwkbHex(lat, lng),
    });
    await _audit('campus_create', targetType: 'campus', detail: {'name': name});
  }

  // ===== FR-ADM-01: ringkasan model (AC-ADM-07) =====

  Future<List<Map<String, dynamic>>> modelVersions() async {
    final rows = await _db
        .from('model_versions')
        .select('id, kind, name, status, dataset_version, metrics, created_at')
        .order('created_at', ascending: false)
        .limit(20);
    return rows;
  }

  /// Count per event_type — read-only (admin tidak bisa ubah metrik).
  // ponytail: batas 1000 baris; agregasi server-side bila data meledak.
  Future<Map<String, int>> interactionCounts() async {
    final rows = await _db
        .from('interactions')
        .select('event_type')
        .limit(1000);
    final counts = <String, int>{};
    for (final r in rows) {
      final k = '${r['event_type']}';
      counts[k] = (counts[k] ?? 0) + 1;
    }
    return counts;
  }
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(Supabase.instance.client),
);

final adminOverviewProvider = FutureProvider<AdminOverview>(
  (ref) => ref.watch(adminRepositoryProvider).overview(),
);
final adminPendingOwnersProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepositoryProvider).pendingOwners(),
);
final adminPendingListingsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepositoryProvider).pendingListings(),
);
final adminOpenReportsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepositoryProvider).openReports(),
);
final adminPendingReviewsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepositoryProvider).pendingReviews(),
);
final adminVisibleReviewsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepositoryProvider).visibleReviews(),
);
final adminFacilitiesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepositoryProvider).facilities(),
);
final adminCampusesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepositoryProvider).campuses(),
);
final adminModelVersionsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepositoryProvider).modelVersions(),
);
final adminInteractionCountsProvider = FutureProvider<Map<String, int>>(
  (ref) => ref.watch(adminRepositoryProvider).interactionCounts(),
);
