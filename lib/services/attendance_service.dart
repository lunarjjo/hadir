/// Alur inti absensi: check-in/check-out dengan geofence + token QR,
/// dan penandaan manual oleh admin.
library;

import 'package:sqflite/sqflite.dart';

import 'package:hadir/core/attendance_rules.dart';
import 'package:hadir/core/geo.dart';
import 'package:hadir/core/id_gen.dart';
import 'package:hadir/core/qr_token.dart';
import 'package:hadir/core/result.dart';
import 'package:hadir/data/dao/attendance_dao.dart';
import 'package:hadir/data/dao/office_dao.dart';
import 'package:hadir/data/dao/user_dao.dart';
import 'package:hadir/data/models/app_settings.dart';
import 'package:hadir/data/models/attendance.dart';
import 'package:hadir/data/models/office.dart';

class AttendanceService {
  final DateTime Function() _clock;
  final AttendanceDao _att;
  final OfficeDao _offices;
  final UserDao _users;

  AttendanceService(Database db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _att = AttendanceDao(db),
        _offices = OfficeDao(db),
        _users = UserDao(db);

  AppErrCode _mapTokenProblem(QrTokenProblem p) => switch (p) {
        QrTokenProblem.badFormat => AppErrCode.badToken,
        QrTokenProblem.badSignature => AppErrCode.badToken,
        QrTokenProblem.expired => AppErrCode.tokenExpired,
        QrTokenProblem.notYetValid => AppErrCode.tokenNotYetValid,
        QrTokenProblem.officeMismatch => AppErrCode.tokenOfficeMismatch,
      };

  /// Absen masuk: geofence → (opsional) token QR → simpan rekaman.
  Future<Result<Attendance>> checkIn({
    required String userId,
    required Office office,
    required double lat,
    required double lng,
    String? tokenRaw,
    required AppSettings settings,
  }) async {
    final now = _clock();
    final day = dayKey(now);
    final existing = await _att.findByUserAndDay(userId, day);
    if (existing != null) return err(AppErrCode.alreadyCheckedIn);

    final geo = checkGeoFence(
      lat: lat,
      lng: lng,
      officeLat: office.latitude,
      officeLng: office.longitude,
      radiusMeters: office.radiusMeters.toDouble(),
    );
    if (!geo.inside) {
      return err(
        AppErrCode.outsideRadius,
        params: {
          'jarak': formatDistance(geo.distance),
          'radius': '${office.radiusMeters} m',
          'nama': office.name,
        },
      );
    }

    var tokenOk = false;
    if (settings.requireQr) {
      final raw = tokenRaw?.trim() ?? '';
      if (raw.isEmpty) return err(AppErrCode.needToken);
      final codec = QrCodec(secretHex: settings.qrSecretHex, clock: () => now);
      final check = codec.verifyOfficeToken(raw, expectedOfficeId: office.id);
      if (!check.valid) return err(_mapTokenProblem(check.problem!));
      tokenOk = true;
    }

    final statusIn = evaluateCheckIn(now, settings.policy);
    final nowMs = now.millisecondsSinceEpoch;
    final record = Attendance(
      id: newId(),
      userId: userId,
      officeId: office.id,
      day: day,
      checkInAtMs: nowMs,
      checkInLat: lat,
      checkInLng: lng,
      checkInDistance: geo.distance,
      checkInGeoOk: true,
      tokenOk: tokenOk,
      checkOutAtMs: null,
      checkOutLat: null,
      checkOutLng: null,
      checkOutDistance: null,
      checkOutGeoOk: null,
      statusIn: statusIn,
      statusOut: null,
      status: overallStatus(statusIn, null),
      method: 'qr',
      note: null,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
    );
    await _att.insert(record);
    return ok(record);
  }

  /// Absen pulang: cari rekaman terbuka (mendukung lintas tengah malam),
  /// verifikasi geofence ulang (bisa diatur), lalu tutup rekaman.
  Future<Result<Attendance>> checkOut({
    required String userId,
    double? lat,
    double? lng,
    required AppSettings settings,
  }) async {
    final now = _clock();
    final open = await _att.findLatestOpen(userId, withinHours: 20, now: now);
    if (open == null) {
      final today = await _att.findByUserAndDay(userId, dayKey(now));
      if (today != null && today.checkOutAtMs != null) {
        return err(AppErrCode.alreadyCheckedOut);
      }
      return err(AppErrCode.noOpenRecord);
    }

    double? outLat;
    double? outLng;
    double? outDistance;
    bool? outGeoOk;
    if (settings.verifyCheckOutGeo) {
      if (lat == null || lng == null) return err(AppErrCode.gpsUnavailable);
      outLat = lat;
      outLng = lng;
      final office = await _offices.findById(open.officeId);
      if (office != null) {
        final geo = checkGeoFence(
          lat: lat,
          lng: lng,
          officeLat: office.latitude,
          officeLng: office.longitude,
          radiusMeters: office.radiusMeters.toDouble(),
        );
        outDistance = geo.distance;
        outGeoOk = geo.inside;
        if (!geo.inside) {
          return err(
            AppErrCode.outsideRadius,
            params: {
              'jarak': formatDistance(geo.distance),
              'radius': '${office.radiusMeters} m',
              'nama': office.name,
            },
          );
        }
      } else {
        // Kantor sudah dihapus admin: jangan blok absen pulang.
        outDistance = 0;
        outGeoOk = false;
      }
    }

    final statusOut = evaluateCheckOut(open.checkInAt, now, settings.policy);
    final updated = _applyCheckOut(
      open,
      at: now,
      lat: outLat,
      lng: outLng,
      distance: outDistance,
      geoOk: outGeoOk,
      statusOut: statusOut,
    );
    await _att.updateFull(updated);
    return ok(updated);
  }

  Attendance _applyCheckOut(
    Attendance base, {
    required DateTime at,
    double? lat,
    double? lng,
    double? distance,
    bool? geoOk,
    required CheckOutStatus statusOut,
  }) {
    final nowMs = at.millisecondsSinceEpoch;
    final statusIn = base.statusIn;
    return Attendance(
      id: base.id,
      userId: base.userId,
      officeId: base.officeId,
      day: base.day,
      checkInAtMs: base.checkInAtMs,
      checkInLat: base.checkInLat,
      checkInLng: base.checkInLng,
      checkInDistance: base.checkInDistance,
      checkInGeoOk: base.checkInGeoOk,
      tokenOk: base.tokenOk,
      checkOutAtMs: nowMs,
      checkOutLat: lat,
      checkOutLng: lng,
      checkOutDistance: distance,
      checkOutGeoOk: geoOk,
      statusIn: statusIn,
      statusOut: statusOut,
      status: overallStatus(statusIn, statusOut),
      method: base.method,
      note: base.note,
      createdAtMs: base.createdAtMs,
      updatedAtMs: nowMs,
    );
  }

  /// Penandaan manual oleh admin (via QR anggota / formulir).
  /// Idempoten terhadap hari: rekaman yang ada dilengkapi, bukan digandakan.
  Future<Result<Attendance>> manualMark({
    required String userId,
    required String officeId,
    required DateTime checkIn,
    DateTime? checkOut,
    String? note,
    required AppSettings settings,
  }) async {
    final user = await _users.findById(userId);
    if (user == null) return err(AppErrCode.notFound);
    final office = await _offices.findById(officeId);
    if (office == null) return err(AppErrCode.notFound);

    final day = dayKey(checkIn);
    final policy = settings.policy;
    final statusIn = evaluateCheckIn(checkIn, policy);
    final statusOut =
        checkOut == null ? null : evaluateCheckOut(checkIn, checkOut, policy);
    final overall = overallStatus(statusIn, statusOut);
    final nowMs = _clock().millisecondsSinceEpoch;

    final existing = await _att.findByUserAndDay(userId, day);
    if (existing == null) {
      final checkInMs = checkIn.millisecondsSinceEpoch;
      final record = Attendance(
        id: newId(),
        userId: userId,
        officeId: officeId,
        day: day,
        checkInAtMs: checkInMs,
        checkInLat: office.latitude,
        checkInLng: office.longitude,
        checkInDistance: 0,
        checkInGeoOk: true,
        tokenOk: true,
        checkOutAtMs: checkOut?.millisecondsSinceEpoch,
        checkOutLat: checkOut == null ? null : office.latitude,
        checkOutLng: checkOut == null ? null : office.longitude,
        checkOutDistance: checkOut == null ? null : 0,
        checkOutGeoOk: checkOut == null ? null : true,
        statusIn: statusIn,
        statusOut: statusOut,
        status: overall,
        method: 'manual',
        note: note,
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      );
      await _att.insert(record);
      return ok(record);
    }

    // Rekaman hari itu sudah ada: lengkapi pulang bila masih terbuka.
    if (checkOut != null && existing.checkOutAtMs == null) {
      final updated = _applyCheckOut(
        existing,
        at: checkOut,
        lat: office.latitude,
        lng: office.longitude,
        distance: 0,
        geoOk: true,
        statusOut: evaluateCheckOut(existing.checkInAt, checkOut, policy),
      );
      final withNote = _withNote(updated, note);
      await _att.updateFull(withNote);
      return ok(withNote);
    }
    if (note != null && note != existing.note) {
      final updated = _withNote(existing, note);
      await _att.updateFull(updated);
      return ok(updated);
    }
    return ok(existing);
  }

  Attendance _withNote(Attendance base, String? note) => Attendance(
        id: base.id,
        userId: base.userId,
        officeId: base.officeId,
        day: base.day,
        checkInAtMs: base.checkInAtMs,
        checkInLat: base.checkInLat,
        checkInLng: base.checkInLng,
        checkInDistance: base.checkInDistance,
        checkInGeoOk: base.checkInGeoOk,
        tokenOk: base.tokenOk,
        checkOutAtMs: base.checkOutAtMs,
        checkOutLat: base.checkOutLat,
        checkOutLng: base.checkOutLng,
        checkOutDistance: base.checkOutDistance,
        checkOutGeoOk: base.checkOutGeoOk,
        statusIn: base.statusIn,
        statusOut: base.statusOut,
        status: base.status,
        method: base.method,
        note: note ?? base.note,
        createdAtMs: base.createdAtMs,
        updatedAtMs: _clock().millisecondsSinceEpoch,
      );

  Future<void> updateNote(String recordId, String? note) =>
      _att.updateNote(recordId, note);
}
