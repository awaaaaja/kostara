import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../discovery/discovery_repository.dart';

final _detailProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, id) => ref.watch(discoveryProvider).propertyDetail(id),
);

final _roomsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
      (ref, id) => ref.watch(discoveryProvider).propertyRooms(id),
    );

final _reviewsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
      (ref, id) => ref.watch(discoveryProvider).propertyReviews(id),
    );

class PropertyDetailScreen extends ConsumerWidget {
  const PropertyDetailScreen({super.key, required this.propertyId});

  final String propertyId;

  String? _coverUrl(dynamic images) {
    if (images is! List || images.isEmpty) return null;
    final sorted = [...images]
      ..sort((a, b) {
        final ai = (a['is_cover'] == true) ? 1 : 0;
        final bi = (b['is_cover'] == true) ? 1 : 0;
        if (ai != bi) return bi - ai;
        return ((b['sort_order'] ?? 0) as num).compareTo(
          (a['sort_order'] ?? 0) as num,
        );
      });
    final path = sorted.first['storage_path'] as String?;
    if (path == null) return null;
    return Supabase.instance.client.storage
        .from('property-images')
        .getPublicUrl(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_detailProvider(propertyId));
    final rooms = ref.watch(_roomsProvider(propertyId));
    final reviews = ref.watch(_reviewsProvider(propertyId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail kos')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                e is StateError
                    ? 'Kos tidak ditemukan.'
                    : 'Gagal memuat detail.',
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(_detailProvider(propertyId)),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
        data: (data) {
          final cover = _coverUrl(data['property_images']);
          final facilities =
              (data['property_facilities'] as List?)
                  ?.map((e) => '${e['facilities']?['name']}')
                  .toList() ??
              const <String>[];
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              SizedBox(
                height: 200,
                width: double.infinity,
                child: cover == null
                    ? ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.home_outlined, size: 48),
                      )
                    : Image.network(
                        cover,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, st) => ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data['name']}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data['address'] ?? ''}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.person_outline, size: 16),
                          label: Text(_genderLabel('${data['gender_policy']}')),
                        ),
                        Chip(
                          avatar: const Icon(Icons.verified_outlined, size: 16),
                          label: Text('${data['verification_status']}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (data['description'] != null)
                      Text('${data['description']}'),
                    if (facilities.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Fasilitas',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in facilities) Chip(label: Text(f)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Kamar',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    rooms.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(8),
                        child: LinearProgressIndicator(),
                      ),
                      error: (e, _) => const Text('Gagal memuat kamar.'),
                      data: (list) => list.isEmpty
                          ? const Text('Belum ada data kamar.')
                          : Column(
                              children: [
                                for (final r in list)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.meeting_room_outlined,
                                    ),
                                    title: Text(
                                      '${r['code']} · ${r['room_type']}',
                                    ),
                                    subtitle: Text('Rp${r['price']} / bulan'),
                                    trailing: Chip(
                                      label: Text('${r['status']}'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ulasan terverifikasi',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    reviews.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(8),
                        child: LinearProgressIndicator(),
                      ),
                      error: (e, _) => const Text('Gagal memuat ulasan.'),
                      data: (list) => list.isEmpty
                          ? const Text('Belum ada ulasan.')
                          : Column(
                              children: [
                                for (final r in list)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      Icons.star_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    title: Text(
                                      'Rating ${r['rating_overall']}',
                                    ),
                                    subtitle: Text('${r['review_text'] ?? ''}'),
                                  ),
                              ],
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
  }

  String _genderLabel(String v) => switch (v) {
    'male_only' => 'Putra',
    'female_only' => 'Putri',
    _ => 'Campur',
  };
}
