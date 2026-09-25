import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../compare/compare_state.dart';
import '../discovery/property_card.dart';
import 'favorites_repository.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(favoriteSummariesProvider);
    final compareIds = ref.watch(compareIdsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tersimpan'),
        actions: [
          TextButton.icon(
            onPressed: compareIds.isEmpty
                ? null
                : () => context.push('/compare'),
            icon: const Icon(Icons.compare_arrows),
            label: Text('Bandingkan (${compareIds.length})'),
          ),
        ],
      ),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text('Gagal memuat daftar tersimpan.'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(favoriteSummariesProvider),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 48,
                      color: scheme.outline,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada kos tersimpan.\nKetuk hati di halaman detail.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => context.go('/explore'),
                      child: const Text('Cari kos'),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(favoriteIdsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final p = list[i];
                final inCompare = compareIds.contains(p.id);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PropertyCard(
                      property: p,
                      onTap: () => context.push('/property/${p.id}'),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Hapus dari tersimpan',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.favorite, color: scheme.error),
                            onPressed: () => toggleFavorite(ref, p.id),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: () {
                              final msg = inCompare
                                  ? null
                                  : ref
                                        .read(compareIdsProvider.notifier)
                                        .add(p.id);
                              if (msg != null) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(msg)));
                              } else if (!inCompare) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Ditambahkan ke perbandingan',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: Icon(
                              inCompare
                                  ? Icons.check_box
                                  : Icons.compare_arrows,
                              size: 18,
                            ),
                            label: Text(
                              inCompare ? 'Dibandingkan' : 'Bandingkan',
                            ),
                          ),
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
