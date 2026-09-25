import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

/// Encode/decode titik EWKB (SRID 4326) — kontrak geospatial Supabase
/// (PostgREST mengembalikan kolom geography sebagai hex EWKB).

String latLngToEwkbHex(double lat, double lng) {
  final b = BytesBuilder();
  b.addByte(1); // little endian
  final type = ByteData(4)..setUint32(0, 0x20000001, Endian.little);
  b.add(type.buffer.asUint8List());
  final srid = ByteData(4)..setUint32(0, 4326, Endian.little);
  b.add(srid.buffer.asUint8List());
  final coords = ByteData(16)
    ..setFloat64(0, lng, Endian.little)
    ..setFloat64(8, lat, Endian.little);
  b.add(coords.buffer.asUint8List());
  return b.toBytes().map((e) => e.toRadixString(16).padLeft(2, '0')).join();
}

LatLng? ewkbHexToLatLng(String? hex) {
  if (hex == null || hex.length != 50) return null;
  final bytes = Uint8List(25);
  for (var i = 0; i < 25; i++) {
    final part = hex.substring(i * 2, i * 2 + 2);
    final v = int.tryParse(part, radix: 16);
    if (v == null) return null;
    bytes[i] = v;
  }
  final bd = ByteData.view(bytes.buffer);
  if (bd.getUint8(0) != 1) return null;
  if (bd.getUint32(1, Endian.little) & 0x7FFFFFFF != 1) return null;
  final lng = bd.getFloat64(9, Endian.little);
  final lat = bd.getFloat64(17, Endian.little);
  return LatLng(lat, lng);
}
