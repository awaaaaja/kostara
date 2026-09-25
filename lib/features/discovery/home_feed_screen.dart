import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/events/event_logger.dart';
import '../../core/util/payment_schedule.dart';
import '../tenancy/tenancy_repository.dart';
import 'discovery_repository.dart';
import 'models.dart';
import 'property_card.dart';

/// Satu item feed: ringkasan hasil hydrasi + skor/alasan dari feed RPC.
class FeedItem {
  const FeedItem({
    required this.property,
    required this.score,
    required this.reasons,
    required this.rank,
  });

  final PropertySummary property;
  final int score;
  final List<String> reasons;
  final int rank;
}

class HomeFeed {
  const HomeFeed({
    required this.items,
    required this.modelName,
    this.fallback = false,
  });

  final List<FeedItem> items;
  final String modelName;

  /// True bila feed RPC gagal dan UI menampilkan ranking fallback populer
  /// (AC-REC-03) — tanpa klaim personalisasi (DESIGN §35).
  final bool fallback;
}

/// Feed home: `feed_recommendations` (skor 0–100 server-side, impression
/// server-side) → hydrate ringkasan dalam 1 query; RPC gagal → ranking
/// fallback populer sehingga feed tak pernah kosong (AC-REC-03).
final homeFeedProvider = FutureProvider<HomeFeed>((ref) async {
  final repo = ref.watch(discoveryProvider);
  var fallback = false;
  List<dynamic> raw;
  String modelName;
  try {
    final feed = await repo.feed();
    raw = (feed['items'] as List?) ?? const [];
    modelName = '${feed['model_name'] ?? 'baseline-none'}';
  } catch (_) {
    fallback = true;
    final res = await repo.search(sort: 'popularity', pageSize: 12);
    raw = res.items
        .map((s) => {'property_id': s.id, 'score': 0, 'reason_codes': []})
        .toList();
    modelName = 'baseline-fallback';
  }
  final ids = raw
      .map((e) => (e as Map<String, dynamic>)['property_id'] as String)
      .toList();
  final summaries = await repo.propertiesByIds(ids);
  final byId = {for (final s in summaries) s.id: s};
  final items = <FeedItem>[];
  for (final e in raw) {
    final m = e as Map<String, dynamic>;
    final s = byId[m['property_id'] as String];
    if (s == null) continue;
    items.add(
      FeedItem(
        property: s,
        score: (m['score'] as num?)?.toInt() ?? 0,
        reasons:
            ((m['reasons_raw'] as List?) ??
                    (m['reason_codes'] as List?) ??
                    const [])
                .map((e) => '$e')
                .toList(),
        rank: (m['rank'] as num?)?.toInt() ?? 0,
      ),
    );
  }
  if (items.isNotEmpty) {
    ref
        .read(eventLoggerProvider)
        .log(
          'recommendation_impression',
          metadata: {
            'surface': 'home',
            'model_name': modelName,
            'count': items.length,
            if (fallback) 'fallback': true,
          },
        );
  }
  return HomeFeed(items: items, modelName: modelName, fallback: fallback);
});

const _reasonLabels = <String, String>{
  'budget_fit': 'Sesuai budget',
  'near_campus': 'Dekat kampus',
  'facility_match': 'Fasilitas cocok',
  'high_verified_rating': 'Rating tinggi',
  'positive_aspects': 'Ulasan positif',
  'trending': 'Sedang populer',
};

class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Beranda')),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text('Gagal memuat rekomendasi.'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(homeFeedProvider),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(homeFeedProvider),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const _PaymentBanner(),
                  const SizedBox(height: 12),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.explore_outlined,
                            size: 48,
                            color: scheme.outline,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Belum ada rekomendasi.\nJelajahi kos untuk mulai menemukan.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () => context.go('/explore'),
                            child: const Text('Buka pencarian'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(homeFeedProvider);
              ref.invalidate(paymentSummaryProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: data.items.length + 2,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == 0) return const _PaymentBanner();
                if (i == 1) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.fallback
                              ? 'Populer saat ini'
                              : 'Rekomendasi untukmu',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (data.fallback)
                          Text(
                            'Rekomendasi personal tidak tersedia — '
                            'menampilkan kos populer.',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
                    ),
                  );
                }
                final item = data.items[i - 2];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PropertyCard(
                      property: item.property,
                      onTap: () =>
                          context.push('/property/${item.property.id}'),
                    ),
                    // Skor/alasan hanya untuk ranking model; fallback
                    // populer tidak menampilkan angka yang menyesatkan.
                    if (!data.fallback)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              size: 14,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Skor kecocokan ${item.score}/100',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: scheme.primary),
                            ),
                            if (item.reasons.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.reasons
                                      .take(3)
                                      .map((r) => _reasonLabels[r] ?? r)
                                      .join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Banner tagihan di home seeker (AC-PAY-06/FR-PAY-04): status berasal dari
/// [PaymentSummary] — helper yang sama dengan dashboard owner sehingga
/// angkanya identik. Tanpa tagihan → tidak ditampilkan (tanpa tile kosong).
class _PaymentBanner extends ConsumerWidget {
  const _PaymentBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(paymentSummaryProvider);
    final scheme = Theme.of(context).colorScheme;
    return summary.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (s) {
        if (s.unpaidCount == 0 || s.nextDueDate == null) {
          return const SizedBox.shrink();
        }
        final due = s.nextDueDate!;
        final now = DateTime.now();
        final overdue = s.nextStatus == 'overdue';
        return Card(
          elevation: 0,
          color: scheme.surfaceContainerLow,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.go('/tenancy'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Icon(
                    overdue ? Icons.warning_amber_outlined : Icons.schedule,
                    color: overdue ? scheme.error : scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tagihan berikutnya',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          '${due.day.toString().padLeft(2, '0')}/'
                          '${due.month.toString().padLeft(2, '0')}/${due.year}'
                          ' · Rp${s.nextAmount}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${paymentStatusLabel(s.nextStatus)} · '
                          '${dueInLabel(due, now)}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: overdue ? scheme.error : null),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
