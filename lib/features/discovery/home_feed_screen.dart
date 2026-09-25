import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/events/event_logger.dart';
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
  const HomeFeed({required this.items, required this.modelName});

  final List<FeedItem> items;
  final String modelName;
}

/// Feed home: `feed_recommendations` (skor 0–100 server-side, impression
/// server-side) → hydrate ringkasan dalam 1 query; fallback state jujur
/// bila feed kosong (tanpa klaim personalisasi).
final homeFeedProvider = FutureProvider<HomeFeed>((ref) async {
  final repo = ref.watch(discoveryProvider);
  final feed = await repo.feed();
  final raw = (feed['items'] as List?) ?? const [];
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
            'model_name': feed['model_name'],
            'count': items.length,
          },
        );
  }
  return HomeFeed(
    items: items,
    modelName: '${feed['model_name'] ?? 'baseline-none'}',
  );
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
            return Center(
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
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(homeFeedProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: data.items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      'Rekomendasi untukmu',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                }
                final item = data.items[i - 1];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PropertyCard(
                      property: item.property,
                      onTap: () =>
                          context.push('/property/${item.property.id}'),
                    ),
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
                            'Kecocokan ${item.score}%',
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
