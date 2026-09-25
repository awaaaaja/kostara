import 'package:supabase_flutter/supabase_flutter.dart';

/// Hasil item `search_properties` / `nearby_properties` (kontrak cp03a §2).
/// `cover_path` = storage_path; URL publik dibangun client (bucket public).
class PropertySummary {
  const PropertySummary({
    required this.id,
    required this.name,
    this.priceFrom,
    this.coverPath,
    this.ratingAvg,
    this.ratingCount = 0,
    this.distanceM,
    this.availability,
    this.genderPolicy,
    this.facilities = const [],
    this.lat,
    this.lng,
  });

  final String id;
  final String name;
  final int? priceFrom;
  final String? coverPath;
  final double? ratingAvg;
  final int ratingCount;
  final int? distanceM;
  final int? availability;
  final String? genderPolicy;
  final List<String> facilities;
  final double? lat;
  final double? lng;

  String? get coverUrl => coverPath == null
      ? null
      : Supabase.instance.client.storage
            .from('property-images')
            .getPublicUrl(coverPath!);

  factory PropertySummary.fromJson(Map<String, dynamic> json) =>
      PropertySummary(
        id: json['id'] as String,
        name: json['name'] as String,
        priceFrom: (json['price_from'] as num?)?.toInt(),
        coverPath: json['cover_path'] as String?,
        ratingAvg: (json['rating_avg'] as num?)?.toDouble(),
        ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
        distanceM: (json['distance_m'] as num?)?.toInt(),
        availability: (json['availability'] as num?)?.toInt(),
        genderPolicy: json['gender_policy'] as String?,
        facilities:
            (json['facilities'] as List?)?.map((e) => '$e').toList() ??
            const [],
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
      );

  /// Serialisasi cache offline (AC-OFF-01) — simetris dengan [fromJson].
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price_from': priceFrom,
    'cover_path': coverPath,
    'rating_avg': ratingAvg,
    'rating_count': ratingCount,
    'distance_m': distanceM,
    'availability': availability,
    'gender_policy': genderPolicy,
    'facilities': facilities,
    'lat': lat,
    'lng': lng,
  };
}

class SearchResult {
  const SearchResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasMore,
    this.fromCache = false,
  });

  final List<PropertySummary> items;
  final int page;
  final int pageSize;
  final bool hasMore;

  /// True bila disajikan dari cache lokal (koneksi bermasalah) — banner
  /// offline di UI (AC-OFF-01).
  final bool fromCache;

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
    items: ((json['items'] as List?) ?? const [])
        .map((e) => PropertySummary.fromJson(e as Map<String, dynamic>))
        .toList(),
    page: (json['page'] as num?)?.toInt() ?? 1,
    pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
    hasMore: json['has_more'] as bool? ?? false,
  );
}

class Campus {
  const Campus({
    required this.id,
    required this.name,
    this.locationLabel = '',
    this.lat,
    this.lng,
  });

  final String id;
  final String name;
  final String locationLabel;
  final double? lat;
  final double? lng;

  bool get hasLocation => lat != null && lng != null;

  factory Campus.fromJson(Map<String, dynamic> json) => Campus(
    id: json['id'] as String,
    name: json['name'] as String,
    locationLabel: json['location_label'] as String? ?? '',
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
  );
}
