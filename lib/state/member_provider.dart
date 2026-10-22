/// State sisi anggota: rekaman hari ini, alur absen, riwayat, QR pribadi.
library;

import 'package:flutter/foundation.dart';

import 'package:hadir/core/attendance_rules.dart';
import 'package:hadir/core/result.dart';
import 'package:hadir/data/dao/attendance_dao.dart';
import 'package:hadir/data/models/attendance.dart';
import 'package:hadir/data/models/office.dart';
import 'package:hadir/data/models/user.dart';
import 'package:hadir/services/attendance_service.dart';
import 'package:hadir/state/settings_provider.dart';

class MemberProvider extends ChangeNotifier {
  final AttendanceService _attendance;
  final SettingsProvider _settings;
  final AttendanceDao _dao;

  User? _user;
  Attendance? _today;
  bool _busy = false;

  MemberProvider(this._attendance, this._settings, this._dao);

  User? get user => _user;
  Attendance? get today => _today;
  bool get busy => _busy;

  /// Dipanggil AuthProvider saat user aktif berubah.
  void attach(User? user) {
    _user = user;
    _today = null;
    if (user != null) {
      refreshToday();
    }
    notifyListeners();
  }

  Future<void> refreshToday() async {
    if (_user == null) return;
    _today = await _dao.findByUserAndDay(
      _user!.id,
      dayKey(DateTime.now()),
    );
    notifyListeners();
  }

  Future<Result<Attendance>> doCheckIn({
    required Office office,
    required double lat,
    required double lng,
    String? tokenRaw,
  }) async {
    if (_user == null) return err(AppErrCode.generic);
    _busy = true;
    notifyListeners();
    try {
      final result = await _attendance.checkIn(
        userId: _user!.id,
        office: office,
        lat: lat,
        lng: lng,
        tokenRaw: tokenRaw,
        settings: _settings.settings,
      );
      if (result is Ok<Attendance>) {
        _today = result.value;
      }
      return result;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<Result<Attendance>> doCheckOut({
    required double lat,
    required double lng,
  }) async {
    if (_user == null) return err(AppErrCode.generic);
    _busy = true;
    notifyListeners();
    try {
      final result = await _attendance.checkOut(
        userId: _user!.id,
        lat: lat,
        lng: lng,
        settings: _settings.settings,
      );
      if (result is Ok<Attendance>) {
        _today = result.value;
      }
      return result;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Riwayat pribadi dalam rentang waktu.
  Future<List<Attendance>> historyRange(DateTime from, DateTime to) async {
    if (_user == null) return const [];
    return _dao.historyByUser(
      _user!.id,
      fromMs: from.millisecondsSinceEpoch,
      toMs: to.millisecondsSinceEpoch,
    );
  }

  /// Rekap status pribadi bulan ini.
  Future<Map<String, int>> monthlyStats() async {
    if (_user == null) return const {};
    final now = DateTime.now();
    final awal = DateTime(now.year, now.month, 1);
    final akhir = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return _dao.statusCountsForUser(_user!.id, dayKey(awal), dayKey(akhir));
  }

  /// Payload QR identitas pribadi (kartu untuk absen manual oleh admin).
  String? get myQrPayload {
    final user = _user;
    if (user == null) return null;
    return _settings.qrCodec.memberPayload(
      userId: user.id,
      username: user.username,
    );
  }
}
