import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'discovery_providers.dart';

/// Kamera peta state terpisah dari filter (sinkron lewat searchResultProvider
/// yang sama dengan list — AC-MAP-01: satu sumber hasil).
final mapCenterProvider = StateProvider<LatLng>(
  (ref) => const LatLng(-0.9210, 100.4865), // Padang (dev default)
);

class ExploreMapScreen extends ConsumerStatefulWidget {
  const ExploreMapScreen({super.key});

  @override
  ConsumerState<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends ConsumerState<ExploreMapScreen> {
  final _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(searchResultProvider);
    final center = ref.watch(mapCenterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Peta kos')),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text('Gagal memuat peta.'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(searchResultProvider),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
        data: (data) {
          final points = [
            for (final p in data.items)
              if (p.lat != null && p.lng != null) p,
          ];
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13,
                  cameraConstraint: CameraConstraint.contain(
                    bounds: LatLngBounds(
                      const LatLng(-1.2, 100.1),
                      const LatLng(-0.6, 100.8),
                    ),
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'dev.kostara.app',
                  ),
                  MarkerLayer(
                    markers: [
                      for (final p in points)
                        Marker(
                          point: LatLng(p.lat!, p.lng!),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => _showPreview(
                              context,
                              p.id,
                              p.name,
                              p.priceFrom,
                              p.ratingAvg,
                            ),
                            child: Icon(
                              Icons.location_on,
                              size: 36,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (points.isEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Tidak ada titik kos di filter saat ini. Ubah filter di tab Cari kos.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showPreview(
    BuildContext context,
    String id,
    String name,
    int? price,
    double? rating,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.home_outlined),
          title: Text(name),
          subtitle: Text(
            [
              if (price != null) 'Rp$price / bulan',
              if (rating != null) 'Rating ${rating.toStringAsFixed(1)}',
            ].join(' · '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(ctx).pop();
            context.push('/property/$id');
          },
        ),
      ),
    );
  }
}
