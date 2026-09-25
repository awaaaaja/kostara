import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/util/ewkb.dart';
import 'models.dart';

/// Akses data discovery. Semua spatial query lewat RPC SECURITY INVOKER
/// (RLS aktif) — tidak ada klien yang menghitung jarak/ETA sendiri.
class DiscoveryRepository {
  DiscoveryRepository(this._db);

  final SupabaseClient _db;

  /// [filters] harus memakai allow-list key cp03a §2
  /// (q, price_min/max, gender, room_types, facility_ids, rating_min,
  /// available_only, campus_id, max_distance_m, move_in_from).
  Future<SearchResult> search({
    Map<String, dynamic>? filters,
    String sort = 'relevansi',
    int page = 1,
    int pageSize = 20,
    List<double>? bbox,
    double? nearLat,
    double? nearLng,
    int? nearRadiusM,
  }) async {
    final data = await _db.rpc(
      'search_properties',
      params: {
        if (filters != null && filters.isNotEmpty) 'p_filters': filters,
        'p_sort': sort,
        'p_page': page,
        'p_page_size': pageSize,
        'p_bbox': ?bbox,
        'p_near_lat': ?nearLat,
        'p_near_lng': ?nearLng,
        'p_near_radius_m': ?nearRadiusM,
      },
    );
    return SearchResult.fromJson(data as Map<String, dynamic>);
  }

  /// Feed rekomendasi (cp03a §3): `{items:[{property_id, display_name, score,
  /// rank, reason_codes}], model_name}`. server-side fallback — selalu isi
  /// selama ada property listable; impression log server-side.
  Future<Map<String, dynamic>> feed({int limit = 12}) async {
    final data = await _db.rpc(
      'feed_recommendations',
      params: {'p_limit': limit},
    );
    return data as Map<String, dynamic>;
  }

  /// Hydrasi ringkasan feed (harga/ketersediaan/cover) dalam 1 query; RLS aktif.
  Future<List<PropertySummary>> propertiesByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _db
        .from('properties')
        .select('''
          id, name, gender_policy,
          rooms(price, status),
          property_images(storage_path, is_cover, sort_order)
        ''')
        .inFilter('id', ids);
    return rows.map((r) {
      final rooms = (r['rooms'] as List?) ?? const [];
      final available = rooms.where((x) => x['status'] == 'available').toList();
      final prices = available
          .map((x) => (x['price'] as num?)?.toInt())
          .whereType<int>()
          .toList();
      final images = ((r['property_images'] as List?) ?? const []).toList()
        ..sort((a, b) {
          final ai = (a['is_cover'] == true) ? 1 : 0;
          final bi = (b['is_cover'] == true) ? 1 : 0;
          if (ai != bi) return bi - ai;
          return ((b['sort_order'] ?? 0) as num).compareTo(
            (a['sort_order'] ?? 0) as num,
          );
        });
      return PropertySummary(
        id: r['id'] as String,
        name: r['name'] as String,
        priceFrom: prices.isEmpty
            ? null
            : prices.reduce((a, b) => a < b ? a : b),
        availability: available.length,
        genderPolicy: r['gender_policy'] as String?,
        coverPath: images.isEmpty
            ? null
            : images.first['storage_path'] as String?,
      );
    }).toList();
  }

  Future<List<Campus>> campusSuggestions(String query) async {
    final data = await _db.rpc(
      'campus_suggestions',
      params: {'p_q': query, 'p_limit': 8},
    );
    final items = (data['items'] as List?) ?? const [];
    return items
        .map((e) => Campus.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Campus>> allCampuses() async {
    final data = await _db
        .from('campuses')
        .select('id, name, address, location')
        .eq('is_active', true)
        .order('name');
    return data
        .map(
          (e) => Campus.fromJson({
            'id': e['id'],
            'name': e['name'],
            'location_label': e['address'],
            'lat': ewkbHexToLatLng(e['location'] as String?)?.latitude,
            'lng': ewkbHexToLatLng(e['location'] as String?)?.longitude,
          }),
        )
        .toList();
  }

  Future<Map<String, dynamic>> propertyDetail(String id) async {
    final data = await _db
        .from('properties')
        .select('''
          *, property_images(id, storage_path, is_cover, sort_order),
          property_facilities(facilities(name))
        ''')
        .eq('id', id)
        .maybeSingle();
    if (data == null) {
      throw StateError('properti_tidak_ditemukan');
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> propertyRooms(String id) async {
    final data = await _db
        .from('rooms')
        .select('id, code, room_type, price, status')
        .eq('property_id', id)
        .order('price');
    return data;
  }

  Future<List<Map<String, dynamic>>> propertyReviews(String id) async {
    final data = await _db
        .from('reviews')
        .select('id, rating_overall, review_text, created_at, status')
        .eq('property_id', id)
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .limit(20);
    return data;
  }
}

final discoveryProvider = Provider<DiscoveryRepository>(
  (ref) => DiscoveryRepository(Supabase.instance.client),
);
