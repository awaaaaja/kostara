import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../discovery/discovery_providers.dart';
import '../discovery/models.dart';

class PropertyListScreen extends ConsumerStatefulWidget {
  const PropertyListScreen({super.key});

  @override
  ConsumerState<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends ConsumerState<PropertyListScreen> {
  final _query = TextEditingController();
  Campus? _campus;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final filters = <String, dynamic>{'available_only': true};
    if (_query.text.trim().isNotEmpty) filters['q'] = _query.text.trim();
    if (_campus != null) {
      filters['campus_id'] = _campus!.id;
      filters['max_distance_m'] = 3000;
    }
    ref.read(searchFiltersProvider.notifier).state = filters;
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(searchResultProvider);
    final campuses = ref.watch(campusesProvider);
    final sort = ref.watch(searchSortProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cari kos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Nama kos atau alamat',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _query.clear();
                    _applyFilters();
                  },
                ),
              ),
              onSubmitted: (_) => _applyFilters(),
            ),
          ),
          SizedBox(
            height: 56,
            child: campuses.when(
              data: (list) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Semua kampus'),
                      selected: _campus == null,
                      onSelected: (_) {
                        setState(() => _campus = null);
                        _applyFilters();
                      },
                    ),
                  ),
                  for (final c in list)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c.name),
                        selected: _campus?.id == c.id,
                        onSelected: (_) {
                          setState(() => _campus = c);
                          _applyFilters();
                        },
                      ),
                    ),
                ],
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                ),
              ),
              error: (e, _) => const SizedBox.shrink(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.sort, size: 18),
                const SizedBox(width: 8),
                const Text('Urutkan:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: sort,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: 'relevansi',
                      child: Text('Relevansi'),
                    ),
                    DropdownMenuItem(value: 'harga', child: Text('Harga')),
                    DropdownMenuItem(value: 'jarak', child: Text('Jarak')),
                    DropdownMenuItem(
                      value: 'popularity',
                      child: Text('Populer'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(searchSortProvider.notifier).state = v;
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: result.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorRetry(
                message: 'Gagal memuat. Periksa koneksi.',
                onRetry: () => ref.invalidate(searchResultProvider),
              ),
              data: (data) {
                if (data.items.isEmpty) {
                  return const _Empty(
                    icon: Icons.search_off,
                    message:
                        'Belum ada kos yang cocok.\nCoba ubah filter atau kampus.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: data.items.length + (data.hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    if (i == data.items.length) {
                      return Center(
                        child: TextButton.icon(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(searchResultProvider.notifier)
                                  .loadMore();
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Gagal memuat halaman berikutnya',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.expand_more),
                          label: const Text('Muat lebih banyak'),
                        ),
                      );
                    }
                    return _PropertyCard(
                      property: data.items[i],
                      onTap: () =>
                          context.push('/property/${data.items[i].id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property, this.onTap});

  final PropertySummary property;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final price = property.priceFrom;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: property.coverUrl == null
                  ? ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: const Icon(Icons.home_outlined),
                    )
                  : Image.network(
                      property.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price == null
                          ? 'Harga menyusul'
                          : 'Rp${price.toString()} / bulan',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: scheme.primary,
                        ),
                        Text(
                          property.ratingCount > 0
                              ? '${property.ratingAvg?.toStringAsFixed(1)} (${property.ratingCount})'
                              : 'Belum ada ulasan',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (property.distanceM != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${property.distanceM} m',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    if (property.availability != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${property.availability} kamar tersedia',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: scheme.primary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}
