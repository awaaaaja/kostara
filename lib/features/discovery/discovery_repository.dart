import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        .select('id, name, address')
        .eq('is_active', true)
        .order('name');
    return data
        .map(
          (e) => Campus.fromJson({
            'id': e['id'],
            'name': e['name'],
            'location_label': e['address'],
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
