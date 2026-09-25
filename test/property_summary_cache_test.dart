import 'package:flutter_test/flutter_test.dart';

import 'package:kostara/features/discovery/models.dart';

void main() {
  group('PropertySummary cache roundtrip (AC-OFF-01)', () {
    test('toJson → fromJson mempertahankan semua field', () {
      const original = PropertySummary(
        id: 'p-1',
        name: 'Kos Melati',
        priceFrom: 850000,
        coverPath: 'p-1/foto.jpg',
        ratingAvg: 4.5,
        ratingCount: 12,
        distanceM: 750,
        availability: 2,
        genderPolicy: 'female_only',
        facilities: ['wifi', 'parkir'],
        lat: -0.92,
        lng: 100.48,
      );
      final restored = PropertySummary.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.priceFrom, original.priceFrom);
      expect(restored.coverPath, original.coverPath);
      expect(restored.ratingAvg, original.ratingAvg);
      expect(restored.ratingCount, original.ratingCount);
      expect(restored.distanceM, original.distanceM);
      expect(restored.availability, original.availability);
      expect(restored.genderPolicy, original.genderPolicy);
      expect(restored.facilities, original.facilities);
      expect(restored.lat, original.lat);
      expect(restored.lng, original.lng);
    });

    test('SearchResult default bukan dari cache', () {
      const res = SearchResult(
        items: [],
        page: 1,
        pageSize: 20,
        hasMore: false,
      );
      expect(res.fromCache, isFalse);
      const cached = SearchResult(
        items: [],
        page: 1,
        pageSize: 20,
        hasMore: false,
        fromCache: true,
      );
      expect(cached.fromCache, isTrue);
    });
  });
}
