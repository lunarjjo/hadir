/// Model rekaman absensi satu hari per pengguna.
library;

import 'package:hadir/core/attendance_rules.dart';

class Attendance {
  final String id;
  final String userId;
  final String officeId;

  /// Kunci hari lokal `YYYY-MM-DD` (dari waktu check-in).
  final String day;

  final int checkInAtMs;
  final double checkInLat;
  final double checkInLng;
  final double checkInDistance;
  final bool checkInGeoOk;
  final bool tokenOk;

  final int? checkOutAtMs;
  final double? checkOutLat;
  final double? checkOutLng;
  final double? checkOutDistance;
  final bool? checkOutGeoOk;

  final CheckInStatus statusIn;
  final CheckOutStatus? statusOut;

  /// Status gabungan: hadir / terlambat / pulang_awal / lembur.
  final String status;

  /// 'qr' (mandiri) atau 'manual' (dicatat admin).
  final String method;
  final String? note;
  final int createdAtMs;
  final int updatedAtMs;

  const Attendance({
    required this.id,
    required this.userId,
    required this.officeId,
    required this.day,
    required this.checkInAtMs,
    required this.checkInLat,
    required this.checkInLng,
    required this.checkInDistance,
    required this.checkInGeoOk,
    required this.tokenOk,
    required this.checkOutAtMs,
    required this.checkOutLat,
    required this.checkOutLng,
    required this.checkOutDistance,
    required this.checkOutGeoOk,
    required this.statusIn,
    required this.statusOut,
    required this.status,
    required this.method,
    required this.note,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  DateTime get checkInAt => DateTime.fromMillisecondsSinceEpoch(checkInAtMs);

  DateTime? get checkOutAt => checkOutAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(checkOutAtMs!);

  /// Durasi kerja dalam menit (null bila belum pulang).
  int? get workedMinutes =>
      checkOutAtMs == null ? null : (checkOutAtMs! - checkInAtMs) ~/ 60000;

  bool get isManual => method == 'manual';

  factory Attendance.fromMap(Map<String, Object?> m) => Attendance(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        officeId: m['office_id'] as String,
        day: m['day'] as String,
        checkInAtMs: m['check_in_at'] as int,
        checkInLat: m['check_in_lat'] as double,
        checkInLng: m['check_in_lng'] as double,
        checkInDistance: m['check_in_distance'] as double,
        checkInGeoOk: (m['check_in_geo_ok'] as int) == 1,
        tokenOk: (m['token_ok'] as int) == 1,
        checkOutAtMs: m['check_out_at'] as int?,
        checkOutLat: m['check_out_lat'] as double?,
        checkOutLng: m['check_out_lng'] as double?,
        checkOutDistance: m['check_out_distance'] as double?,
        checkOutGeoOk: m['check_out_geo_ok'] == null
            ? null
            : (m['check_out_geo_ok'] as int) == 1,
        statusIn:
            m['status_in'] == 'terlambat'
                ? CheckInStatus.terlambat
                : CheckInStatus.tepat,
        statusOut: _parseOut(m['status_out'] as String?),
        status: m['status'] as String,
        method: m['method'] as String,
        note: m['note'] as String?,
        createdAtMs: m['created_at'] as int,
        updatedAtMs: m['updated_at'] as int,
      );

  static CheckOutStatus? _parseOut(String? s) {
    switch (s) {
      case 'tepat':
        return CheckOutStatus.tepat;
      case 'pulang_awal':
        return CheckOutStatus.pulangAwal;
      case 'lembur':
        return CheckOutStatus.lembur;
      default:
        return null;
    }
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'office_id': officeId,
        'day': day,
        'check_in_at': checkInAtMs,
        'check_in_lat': checkInLat,
        'check_in_lng': checkInLng,
        'check_in_distance': checkInDistance,
        'check_in_geo_ok': checkInGeoOk ? 1 : 0,
        'token_ok': tokenOk ? 1 : 0,
        'check_out_at': checkOutAtMs,
        'check_out_lat': checkOutLat,
        'check_out_lng': checkOutLng,
        'check_out_distance': checkOutDistance,
        'check_out_geo_ok': checkOutGeoOk == null ? null : (checkOutGeoOk! ? 1 : 0),
        'status_in': statusIn == CheckInStatus.terlambat ? 'terlambat' : 'tepat',
        'status_out': switch (statusOut) {
          null => null,
          CheckOutStatus.tepat => 'tepat',
          CheckOutStatus.pulangAwal => 'pulang_awal',
          CheckOutStatus.lembur => 'lembur',
        },
        'status': status,
        'method': method,
        'note': note,
        'created_at': createdAtMs,
        'updated_at': updatedAtMs,
      };
}
