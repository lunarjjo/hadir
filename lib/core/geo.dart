/// Geometri geofence: jarak haversine + pemeriksaan radius.
library;

import 'dart:math' as math;

const double _earthRadiusMeters = 6371008.8;

double _rad(double deg) => deg * math.pi / 180.0;

/// Jarak dua titik koordinat (meter) — rumus haversine bola.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.asin(math.min(1.0, math.sqrt(a)));
  return _earthRadiusMeters * c;
}

/// Hasil pemeriksaan geofence.
class GeoFenceCheck {
  /// Jarak posisi ke pusat kantor (meter).
  final double distance;

  /// Benar bila jarak <= radius (inklusif di batas).
  final bool inside;

  const GeoFenceCheck({required this.distance, required this.inside});
}

/// Periksa apakah posisi berada dalam radius kantor.
GeoFenceCheck checkGeoFence({
  required double lat,
  required double lng,
  required double officeLat,
  required double officeLng,
  required double radiusMeters,
}) {
  final d = distanceMeters(lat, lng, officeLat, officeLng);
  return GeoFenceCheck(distance: d, inside: d <= radiusMeters);
}

/// Format jarak untuk ditampilkan: `82 m` atau `1,24 km`.
String formatDistance(double meters) {
  if (meters < 0) return '0 m';
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(2).replaceAll('.', ',')} km';
}
