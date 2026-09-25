import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 8 aspek wajib review (FR-REV-02, urutan DESIGN §27).
const kReviewAspects = <(String, String)>[
  ('cleanliness', 'Kebersihan'),
  ('security', 'Keamanan'),
  ('internet', 'Internet'),
  ('water', 'Air'),
  ('comfort', 'Kenyamanan'),
  ('access', 'Akses'),
  ('owner', 'Pemilik'),
  ('value', 'Nilai'),
];

/// Alasan laporan (reports.reason_code — teks bebas di DB).
const kReportReasons = <(String, String)>[
  ('spam', 'Spam'),
  ('inappropriate', 'Konten tidak pantas'),
  ('misleading', 'Informasi menyesatkan'),
  ('other', 'Lainnya'),
];

/// Hasil pengecekan kelayakan menulis ulasan final (FR-REV-01,
/// server tetap otoritatif via RLS — ini navigasi UI).
sealed class ReviewEligibility {
  const ReviewEligibility();
}

class ReviewNoTenancy extends ReviewEligibility {
  const ReviewNoTenancy();
}

class ReviewActiveTenancy extends ReviewEligibility {
  const ReviewActiveTenancy();
}

class ReviewAlreadyReviewed extends ReviewEligibility {
  const ReviewAlreadyReviewed();
}

class ReviewEligible extends ReviewEligibility {
  const ReviewEligible(this.tenancyId);
  final String tenancyId;
}

class FeedbackRepository {
  FeedbackRepository(this._db);

  final SupabaseClient _db;

  String get _uid => _db.auth.currentUser!.id;

  /// Eligibility final review: punya tenancy pada property → hanya yang
  /// `ended` dan belum punya review final; status active/none/sudah-mengulas
  /// dipisah untuk copy yang tepat (AC-REV-01..03 tetap dijaga RLS).
  Future<ReviewEligibility> eligibility(String propertyId) async {
    final tenancies = await _db
        .from('tenancies')
        .select('id, status')
        .eq('property_id', propertyId)
        .order('start_date', ascending: false);
    if (tenancies.isEmpty) return const ReviewNoTenancy();
    final ended = tenancies
        .where((t) => t['status'] == 'ended')
        .map((t) => t['id'] as String)
        .toList();
    if (ended.isEmpty) return const ReviewActiveTenancy();
    final reviewed = await _db
        .from('reviews')
        .select('tenancy_id')
        .inFilter('tenancy_id', ended)
        .eq('review_type', 'final');
    final reviewedIds = reviewed.map((r) => r['tenancy_id']).toSet();
    final open = ended.where((id) => !reviewedIds.contains(id));
    if (open.isEmpty) return const ReviewAlreadyReviewed();
    return ReviewEligible(open.first);
  }

  /// Submit review final + 8 skor aspek (FR-REV-02). Validasi ketat di
  /// klien (UX) dan tetap di server (RLS/check/guard).
  Future<void> submitReview({
    required String tenancyId,
    required String propertyId,
    required int overall,
    required Map<String, int> aspects,
    required String text,
  }) {
    if (overall < 1 || overall > 5) {
      throw ArgumentError.value(overall, 'overall', '1..5');
    }
    if (aspects.length != kReviewAspects.length) {
      throw StateError('semua aspek wajib terisi');
    }
    if (text.length > 1000) {
      throw ArgumentError('teks maksimal 1000 karakter');
    }
    return _submit(
      tenancyId: tenancyId,
      propertyId: propertyId,
      overall: overall,
      aspects: aspects,
      text: text,
    );
  }

  Future<void> _submit({
    required String tenancyId,
    required String propertyId,
    required int overall,
    required Map<String, int> aspects,
    required String text,
  }) async {
    final review = await _db
        .from('reviews')
        .insert({
          'tenancy_id': tenancyId,
          'property_id': propertyId,
          'user_id': _uid,
          'review_type': 'final',
          'rating_overall': overall,
          if (text.trim().isNotEmpty) 'review_text': text.trim(),
          'status': 'pending',
        })
        .select('id')
        .single();
    await _db.from('review_aspect_scores').insert([
      for (final e in aspects.entries)
        {
          'review_id': review['id'],
          'aspect': e.key,
          'score': e.value,
          'sentiment': _sentiment(e.value),
          'source': 'manual',
        },
    ]);
  }

  static String _sentiment(int score) => score >= 4
      ? 'positive'
      : score <= 2
      ? 'negative'
      : 'neutral';

  /// Laporkan review atau listing (FR-ADM laporan user).
  Future<void> submitReport({
    required String targetType, // review | property
    required String targetId,
    required String reasonCode,
    String? detail,
  }) async {
    await _db.from('reports').insert({
      'reporter_id': _uid,
      'target_type': targetType,
      'target_id': targetId,
      'reason_code': reasonCode,
      if (detail != null && detail.trim().isNotEmpty) 'detail': detail.trim(),
    });
  }

  /// Review milik saya untuk tenancy (dicek layar sebelum tombol kirim).
  Future<Map<String, dynamic>?> myReview(String tenancyId) async {
    final rows = await _db
        .from('reviews')
        .select('id, status')
        .eq('tenancy_id', tenancyId)
        .eq('review_type', 'final')
        .limit(1);
    return rows.isEmpty ? null : rows.first;
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => FeedbackRepository(Supabase.instance.client),
);
