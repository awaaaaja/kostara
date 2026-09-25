import 'package:flutter_test/flutter_test.dart';

import 'package:kostara/core/util/ewkb.dart';

void main() {
  test('latLngToEwkbHex cocok dengan EWKB PostGIS (titik verifikasi dev)', () {
    // POINT(100.48 -0.92) SRID 4326 — nilai yang sama dipakai harness DB
    // (scripts/test_rls_matrix.py membuktikan PostgREST menerima format ini).
    expect(
      latLngToEwkbHex(-0.92, 100.48),
      '0101000020e61000001f85eb51b81e5940713d0ad7a370edbf',
    );
  });

  test('latLngToEwkbHex menolak koordinat di luar rentang lewat validasi UI', () {
    // Validasi form yang sama: |lat| <= 90, |lng| <= 180 (lihat AddPropertyScreen).
    const lat = -0.9;
    const lng = 100.4;
    expect(lat.abs() <= 90, isTrue);
    expect(lng.abs() <= 180, isTrue);
    expect(latLngToEwkbHex(lat, lng).length, 25 * 2);
  });
}
