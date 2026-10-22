/// Test geofence haversine.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hadir/core/geo.dart';

void main() {
  // Radius bola (m) yang dipakai implementasi.
  const r = 6371008.8;
  const satuDerajatBusur = r * 3.141592653589793 / 180.0; // ≈ 111.195 m

  group('distanceMeters', () {
    test('titik sama → 0', () {
      expect(distanceMeters(-6.2, 106.8, -6.2, 106.8), closeTo(0, 0.001));
    });

    test('1 derajat lintang ≈ 111.195 km', () {
      final d = distanceMeters(0, 0, 1, 0);
      expect(d, closeTo(satuDerajatBusur, 1));
    });

    test('1 derajat bujur di khatulistiwa ≈ 111.195 km', () {
      final d = distanceMeters(0, 0, 0, 1);
      expect(d, closeTo(satuDerajatBusur, 1));
    });

    test('1 derajat bujur di lintang 60° ≈ 55.598 km', () {
      final d = distanceMeters(60, 0, 60, 1);
      expect(d, closeTo(satuDerajatBusur / 2, 2));
    });

    test('antimeridian: 179.999 → -179.999 ≈ ~222 m', () {
      final d = distanceMeters(0, 179.999, 0, -179.999);
      expect(d, lessThan(400));
      expect(d, greaterThan(100));
    });

    test('simetri arah', () {
      final a = distanceMeters(-6.1754, 106.8272, -6.2, 106.85);
      final b = distanceMeters(-6.2, 106.85, -6.1754, 106.8272);
      expect(a, closeTo(b, 0.0001));
    });
  });

  group('checkGeoFence', () {
    test('batas radius inklusif: jarak == radius → di dalam', () {
      final jarakTepat = distanceMeters(0, 0, 0.00045, 0);
      final cek = checkGeoFence(
        lat: 0, lng: 0, officeLat: 0.00045, officeLng: 0,
        radiusMeters: jarakTepat,
      );
      expect(cek.inside, isTrue); // jarak == radius → di dalam
      final luar = checkGeoFence(
        lat: 0, lng: 0, officeLat: 0.00045, officeLng: 0,
        radiusMeters: jarakTepat - 0.5,
      );
      expect(luar.inside, isFalse);
    });

    test('kantor Jakarta: posisi Monas vs 500 m dari Monas', () {
      final diMonas = checkGeoFence(
        lat: -6.175392, lng: 106.827153,
        officeLat: -6.175392, officeLng: 106.827153,
        radiusMeters: 150,
      );
      expect(diMonas.inside, isTrue);
      expect(diMonas.distance, closeTo(0, 0.01));

      final agakJauh = checkGeoFence(
        lat: -6.175392, lng: 106.827153,
        officeLat: -6.18, officeLng: 106.827153,
        radiusMeters: 150,
      );
      // Δlintang 0.004608° ≈ 512 m > 150 m
      expect(agakJauh.inside, isFalse);
      expect(agakJauh.distance, greaterThan(500));
    });
  });

  group('formatDistance', () {
    test('meter dan kilometer', () {
      expect(formatDistance(82.4), '82 m');
      expect(formatDistance(999.6), '1000 m');
      expect(formatDistance(1240), '1,24 km');
      expect(formatDistance(-5), '0 m');
    });
  });
}
