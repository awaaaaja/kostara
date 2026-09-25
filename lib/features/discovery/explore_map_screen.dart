import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'discovery_providers.dart';
import 'models.dart';

/// Kamera peta state terpisah dari filter (sinkron lewat searchResultProvider
/// yang sama dengan list — AC-MAP-01: satu sumber hasil).
final mapCenterProvider = StateProvider<LatLng>(
  (ref) => const LatLng(-0.9210, 100.4865), // Padang (dev default)
);

List<double> _bboxOf(LatLngBounds b) => [
  b.southWest.longitude,
  b.southWest.latitude,
  b.northEast.longitude,
  b.northEast.latitude,
];

class ExploreMapScreen extends ConsumerStatefulWidget {
  const ExploreMapScreen({super.key});

  @override
  ConsumerState<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends ConsumerState<ExploreMapScreen> {
  final _mapController = MapController();

  /// Izin lokasi hanya diminta saat tombol ditekan (JIT, FR-MAP-03);
  /// setelah ditolak, sesi ini tidak memunculkan dialog lagi (AC-MAP-04).
  var _locationAskedOnce = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _nearMe() async {
    final messenger = ScaffoldMessenger.of(context);
    const denyHint =
        'Izin lokasi ditolak. Gunakan pencarian kampus atau geser peta.';
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.deniedForever) {
        messenger.showSnackBar(const SnackBar(content: Text(denyHint)));
        return;
      }
      if (perm == LocationPermission.denied) {
        if (_locationAskedOnce) {
          messenger.showSnackBar(const SnackBar(content: Text(denyHint)));
          return;
        }
        _locationAskedOnce = true;
        perm = await Geolocator.requestPermission();
        if (perm != LocationPermission.whileInUse &&
            perm != LocationPermission.always) {
          messenger.showSnackBar(const SnackBar(content: Text(denyHint)));
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      // Peta berpusat ke posisi saat ini; koordinat TIDAK disimpan/dikirim
      // (FR-PRIV-01) — cukup memindah viewport lalu query bbox.
      final here = LatLng(pos.latitude, pos.longitude);
      _mapController.move(here, 14);
      ref
          .read(mapViewportProvider.notifier)
          .searchBounds(_bboxOf(_mapController.camera.visibleBounds));
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text(denyHint)));
      }
    }
  }

  Future<void> _pickCampus(Campus c) async {
    final picked = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.school_outlined),
          title: Text(c.name),
          subtitle: const Text(
            'Pusatkan peta & saring radius 3 km dari kampus ini',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(ctx).pop(true),
        ),
      ),
    );
    if (picked != true || !mounted) return;
    // Filter dulu (reset viewport), lalu gerakkan kamera, lalu query bbox —
    // urutan post-frame agar reset state filter selesai sebelum query baru.
    final filters = <String, dynamic>{
      ...ref.read(searchFiltersProvider),
      'campus_id': c.id,
      'max_distance_m': 3000,
    };
    ref.read(searchFiltersProvider.notifier).state = filters;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !c.hasLocation) return;
      _mapController.move(LatLng(c.lat!, c.lng!), 14);
      ref
          .read(mapViewportProvider.notifier)
          .searchBounds(_bboxOf(_mapController.camera.visibleBounds));
    });
  }

  @override
  Widget build(BuildContext context) {
    final shared = ref.watch(searchResultProvider);
    final viewport = ref.watch(mapViewportProvider);
    final campuses = ref.watch(campusesProvider);
    final center = ref.watch(mapCenterProvider);
    final scheme = Theme.of(context).colorScheme;

    final sharedItems = shared.valueOrNull?.items;
    final items = viewport.items ?? sharedItems ?? const <PropertySummary>[];
    final showInitialLoading =
        shared.isLoading && viewport.items == null && sharedItems == null;
    final showInitialError =
        shared.hasError && viewport.items == null && sharedItems == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Peta kos')),
      body: Stack(
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
              // Hanya gesture user (bukan move programatik) → debounce
              // 300 ms → tepat 1 query (AC-MAP-02).
              onPositionChanged: (camera, hasGesture) {
                if (!hasGesture) return;
                ref
                    .read(mapViewportProvider.notifier)
                    .cameraStopped(_bboxOf(camera.visibleBounds));
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'dev.kostara.app',
              ),
              MarkerLayer(
                markers: [
                  for (final c in (campuses.valueOrNull ?? const <Campus>[]))
                    if (c.hasLocation)
                      Marker(
                        point: LatLng(c.lat!, c.lng!),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => _pickCampus(c),
                          child: Tooltip(
                            message: c.name,
                            child: Icon(
                              Icons.school,
                              size: 28,
                              color: scheme.tertiary,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (final p in items)
                    if (p.lat != null && p.lng != null)
                      Marker(
                        point: LatLng(p.lat!, p.lng!),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => _showPreview(context, p),
                          child: Icon(
                            Icons.location_on,
                            size: 36,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                ],
              ),
            ],
          ),
          if (showInitialLoading)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (showInitialError)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Gagal memuat peta.',
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(searchResultProvider),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (viewport.loading)
            Positioned(
              left: 16,
              bottom: 96,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mencari di area ini…',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (viewport.dirty && !viewport.loading)
            Positioned(
              left: 16,
              right: 16,
              bottom: 96,
              child: Center(
                child: FilledButton.icon(
                  onPressed: () => ref
                      .read(mapViewportProvider.notifier)
                      .searchBounds(
                        _bboxOf(_mapController.camera.visibleBounds),
                      ),
                  icon: const Icon(Icons.search),
                  label: Text(
                    viewport.error == null ? 'Cari di area ini' : 'Coba lagi',
                  ),
                ),
              ),
            ),
          if (items.isEmpty && !showInitialLoading && !showInitialError)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Tidak ada titik kos di filter saat ini. Ubah filter di '
                    'tab Cari kos atau pilih kampus.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              heroTag: 'map-near-me',
              tooltip: 'Lokasi saya (sekali tekan)',
              onPressed: _nearMe,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  void _showPreview(BuildContext context, PropertySummary p) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.home_outlined),
          title: Text(p.name),
          subtitle: Text(
            [
              if (p.priceFrom != null) 'Rp${p.priceFrom} / bulan',
              if (p.ratingAvg != null)
                'Rating ${p.ratingAvg!.toStringAsFixed(1)}',
            ].join(' · '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(ctx).pop();
            context.push('/property/${p.id}');
          },
        ),
      ),
    );
  }
}
