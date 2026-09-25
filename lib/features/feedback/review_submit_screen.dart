import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/events/event_logger.dart';
import '../discovery/discovery_providers.dart';
import 'feedback_repository.dart';

final _eligibilityProvider = FutureProvider.family<ReviewEligibility, String>((
  ref,
  propertyId,
) {
  // invalidate-able via aksi di layar ini
  ref.watch(_reviewRefreshProvider);
  return ref.watch(feedbackRepositoryProvider).eligibility(propertyId);
});

/// Penanda refresh setelah submit sukses.
final _reviewRefreshProvider = StateProvider<int>((ref) => 0);

/// Tulis ulasan final (FR-REV-01..02, DESIGN §27). Eligibility state jelas;
/// validasi field wajib sebelum submit (AC-REV-04).
class ReviewSubmitScreen extends ConsumerStatefulWidget {
  const ReviewSubmitScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<ReviewSubmitScreen> createState() => _ReviewSubmitScreenState();
}

class _ReviewSubmitScreenState extends ConsumerState<ReviewSubmitScreen> {
  int? _overall;
  final Map<String, int> _aspects = {};
  final _text = TextEditingController();
  bool _submitting = false;
  String? _aspectError;
  bool _overallError = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit(String tenancyId) async {
    if (_submitting) return;
    setState(() {
      _overallError = _overall == null;
      _aspectError = _aspects.length == kReviewAspects.length
          ? null
          : 'Semua 8 aspek wajib dinilai.';
    });
    if (_overall == null || _aspects.length != kReviewAspects.length) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(feedbackRepositoryProvider)
          .submitReview(
            tenancyId: tenancyId,
            propertyId: widget.propertyId,
            overall: _overall!,
            aspects: Map.of(_aspects),
            text: _text.text,
          );
      ref
          .read(eventLoggerProvider)
          .log('review_submit', propertyId: widget.propertyId);
      ref.read(_reviewRefreshProvider.notifier).state++;
      // tampilan publik ikut menyegar bila ternyata langsung relevan
      ref.invalidate(propertyDetailReviewsProvider(widget.propertyId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ulasan terkirim — menunggu moderasi.')),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim ulasan. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligibility = ref.watch(_eligibilityProvider(widget.propertyId));

    return Scaffold(
      appBar: AppBar(title: const Text('Tulis ulasan')),
      body: eligibility.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Gagal memeriksa kelayakan.'),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () =>
                    ref.invalidate(_eligibilityProvider(widget.propertyId)),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
        data: (el) {
          final (title, note) = switch (el) {
            ReviewNoTenancy() => (
              'Belum bisa mengulas',
              'Kamu belum pernah tinggal di kos ini.',
            ),
            ReviewActiveTenancy() => (
              'Ulasan belum tersedia',
              'Ulasan final dapat ditulis setelah masa sewa berakhir.',
            ),
            ReviewAlreadyReviewed() => (
              'Kamu sudah mengulas',
              'Terima kasih — ulasanmu sedang/menunggu moderasi.',
            ),
            ReviewEligible() => (
              'Bagikan pengalamanmu',
              'Ulasanmu membantu penghuni berikutnya memilih kos.',
            ),
          };
          if (el is! ReviewEligible) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(note, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Kembali'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Form(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(note, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                Text(
                  'Rating keseluruhan',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                _StarRow(
                  value: _overall,
                  onChanged: (v) => setState(() {
                    _overall = v;
                    _overallError = false;
                  }),
                ),
                if (_overallError)
                  Text(
                    'Rating keseluruhan wajib diisi.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Ulasan (opsional, maksimal 1000 karakter)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _text,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    hintText: 'Ceritakan pengalamanmu tinggal di sini…',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Penilaian aspek (wajib)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final (key, label) in kReviewAspects)
                  Row(
                    children: [
                      Expanded(child: Text(label, style: _labelStyle(context))),
                      _StarRow(
                        value: _aspects[key],
                        onChanged: (v) => setState(() {
                          _aspects[key] = v;
                          _aspectError = null;
                        }),
                      ),
                    ],
                  ),
                if (_aspectError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _aspectError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Review publik tidak menampilkan detail tenancy pribadi.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : () => _submit(el.tenancyId),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kirim ulasan'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  TextStyle? _labelStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium;
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: onChanged == null ? null : () => onChanged!(i),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              (value != null && i <= value!) ? Icons.star : Icons.star_border,
              color: (value != null && i <= value!)
                  ? scheme.primary
                  : scheme.outline,
              size: 22,
            ),
            tooltip: '$i dari 5',
          ),
      ],
    );
  }
}
