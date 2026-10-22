/// Pembungkus geolocator: izin, aktifkan layanan, ambil posisi.
///
/// Menggunakan framework LocationManager (bukan Play Services) sehingga
/// bekerja di semua perangkat Android.
library;

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'package:hadir/core/result.dart';

class LocationService {
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> permissionStatus() =>
      Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  /// Buka halaman pengaturan aplikasi (untuk izin ditolak permanen).
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  /// Ambil posisi saat ini dengan seluruh pemeriksaan izin.
  Future<Result<Position>> getCurrent() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return err(AppErrCode.gpsServiceOff);
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      return err(AppErrCode.gpsPermissionDenied);
    }
    if (perm == LocationPermission.deniedForever) {
      return err(AppErrCode.gpsPermissionPermanent);
    }
    try {
      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 25));
      return ok(pos);
    } on TimeoutException {
      return err(AppErrCode.gpsTimeout);
    } catch (_) {
      return err(AppErrCode.gpsUnavailable);
    }
  }
}
