import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/events/event_logger.dart';
import '../../core/util/ewkb.dart';
import '../discovery/home_feed_screen.dart';
import 'compare_state.dart';

class CompareRow {
  const CompareRow({
    required this.id,
    required this.name,
    this.priceFrom,
    this.distanceKm,
    this.availability,
    this.facilities = const [],
    this.ratingAvg,
    this.ratingCount = 0,
    this.positiveAspects = 0,
    this.score,
  });

  final String id;
  final String name;
  final int? priceFrom;
  final double? distanceKm;
  final int? availability;
  final List<String> facilities;
  final double? ratingAvg;
  final int ratingCount;
  final int positiveAspects;
  final int? score;
}

/// Hydrasi 8 kolom compare (FR-CMP-01) dalam 1 query + jarak garis lurus
/// ke kampus utama (bukan waktu tempuh — V1 tanpa routing).
final compareRowsProvider = FutureProvider<List<CompareRow>>((ref) async {
  final ids = ref.watch(compareIdsProvider);
  if (ids.isEmpty) return const [];
  final db = Supabase.instance.client;
  final rows = await db
      .from('properties')
      .select('''
        id, name, location,
        rooms(price, status),
        property_facilities(facilities(name)),
        reviews(status, rating_overall, review_aspect_scores(sentiment))
      ''')
      .inFilter('id', ids);

  // jarak garis lurus ke kampus utama (bila ada preferensi)
  LatLng? origin;
  final user = db.auth.currentUser;
  if (user != null) {
    final prefs = await db
        .from('user_preferences')
        .select('primary_campus_id')
        .eq('user_id', user.id)
        .maybeSingle();
    final campusId = prefs?['primary_campus_id'] as String?;
    if (campusId != null) {
      final campus = await db
          .from('campuses')
          .select('location')
          .eq('id', campusId)
          .maybeSingle();
      origin = ewkbHexToLatLng(campus?['location'] as String?);
    }
  }

  final feedScore = <String, int>{
    for (final item
        in ref.watch(homeFeedProvider).valueOrNull?.items ?? const [])
      item.property.id: item.score,
  };

  final distance = Distance();
  final list = rows.map((r) {
    final rooms = (r['rooms'] as List?) ?? const [];
    final available = rooms.where((x) => x['status'] == 'available').toList();
    final prices = available
        .map((x) => (x['price'] as num?)?.toInt())
        .whereType<int>()
        .toList();
    final facilities = ((r['property_facilities'] as List?) ?? const [])
        .map((e) => '${e['facilities']?['name']}')
        .where((e) => e != 'null')
        .toList();
    final reviews = ((r['reviews'] as List?) ?? const [])
        .where((rv) => rv['status'] == 'approved')
        .toList();
    final ratings = reviews
        .map((rv) => (rv['rating_overall'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    final positives = reviews
        .expand((rv) => (rv['review_aspect_scores'] as List?) ?? const [])
        .where((a) => a['sentiment'] == 'positive')
        .length;

    double? distKm;
    final here = ewkbHexToLatLng(r['location'] as String?);
    if (origin != null && here != null) {
      distKm = distance.as(LengthUnit.Kilometer, origin, here);
    }
    final id = r['id'] as String;
    return CompareRow(
      id: id,
      name: '${r['name']}',
      priceFrom: prices.isEmpty ? null : prices.reduce((a, b) => a < b ? a : b),
      distanceKm: distKm,
      availability: available.length,
      facilities: facilities,
      ratingAvg: ratings.isEmpty
          ? null
          : ratings.reduce((a, b) => a + b) / ratings.length,
      ratingCount: ratings.length,
      positiveAspects: positives,
      score: feedScore[id],
    );
  }).toList();
  return list;
});

class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ids = ref.read(compareIdsProvider);
      for (final id in ids) {
        ref.read(eventLoggerProvider).log('compare_add', propertyId: id);
      }
    });
  }

  String _fmtPrice(int? v) => v == null ? '—' : 'Rp$v';
  String _fmtDist(double? v) => v == null ? '—' : '≈${v.toStringAsFixed(1)} km';
  String _fmtRating(double? avg, int count) =>
      count == 0 ? '—' : '${avg!.toStringAsFixed(1)} ($count)';

  @override
  Widget build(BuildContext context) {
    final ids = ref.watch(compareIdsProvider);
    final rows = ref.watch(compareRowsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bandingkan kos')),
      body: ids.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.compare_arrows,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada kos dipilih.\nTambahkan dari halaman detail (maks 3).',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : rows.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Gagal memuat perbandingan.'),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(compareRowsProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (data) => Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Harga')),
                            DataColumn(label: Text('Jarak')),
                            DataColumn(label: Text('Waktu tempuh')),
                            DataColumn(label: Text('Tersedia')),
                            DataColumn(label: Text('Fasilitas')),
                            DataColumn(label: Text('Rating')),
                            DataColumn(label: Text('Aspek positif')),
                            DataColumn(label: Text('Skor')),
                          ],
                          rows: [
                            for (final r in data)
                              DataRow(
                                cells: [
                                  DataCell(Text(_fmtPrice(r.priceFrom))),
                                  DataCell(Text(_fmtDist(r.distanceKm))),
                                  const DataCell(Text('—')),
                                  DataCell(
                                    Text(
                                      r.availability == null
                                          ? '—'
                                          : '${r.availability} kamar',
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 160,
                                      child: Text(
                                        r.facilities.isEmpty
                                            ? '—'
                                            : r.facilities.join(', '),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _fmtRating(r.ratingAvg, r.ratingCount),
                                    ),
                                  ),
                                  DataCell(Text('${r.positiveAspects}')),
                                  DataCell(
                                    Text(r.score == null ? '—' : '${r.score}%'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'Jarak = garis lurus ke kampus utama (bukan waktu '
                      'tempuh). Waktu tempuh tersedia pada rilis berikutnya.',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
