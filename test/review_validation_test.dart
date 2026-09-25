import 'package:flutter_test/flutter_test.dart';
import 'package:kostara/features/feedback/feedback_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// TP-REV-04 / AC-REV-04: validator review — overall wajib 1..5, 8 aspek
/// wajib, teks ≤1000 karakter. Validasi berjalan sebelum sentuhan jaringan.
void main() {
  // Klien dummy: validasi gagal sebelum request, jadi tak perlu koneksi.
  final repo = FeedbackRepository(
    SupabaseClient('https://example.supabase.co', 'anon-key'),
  );

  Map<String, int> fullAspects() => {for (final (k, _) in kReviewAspects) k: 4};

  test('overall di luar 1..5 ditolak', () {
    expect(
      () => repo.submitReview(
        tenancyId: 't',
        propertyId: 'p',
        overall: 0,
        aspects: fullAspects(),
        text: '',
      ),
      throwsArgumentError,
    );
    expect(
      () => repo.submitReview(
        tenancyId: 't',
        propertyId: 'p',
        overall: 6,
        aspects: fullAspects(),
        text: '',
      ),
      throwsArgumentError,
    );
  });

  test('aspek tidak lengkap ditolak (8 wajib)', () {
    final partial = fullAspects()..remove('water');
    expect(
      () => repo.submitReview(
        tenancyId: 't',
        propertyId: 'p',
        overall: 4,
        aspects: partial,
        text: '',
      ),
      throwsStateError,
    );
    expect(kReviewAspects.length, 8, reason: 'dictionary 8 aspek (FR-REV-02)');
  });

  test('teks > 1000 karakter ditolak', () {
    expect(
      () => repo.submitReview(
        tenancyId: 't',
        propertyId: 'p',
        overall: 4,
        aspects: fullAspects(),
        text: 'a' * 1001,
      ),
      throwsArgumentError,
    );
  });
}
