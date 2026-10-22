/// State sisi admin: dashboard, anggota, kantor, rekap, QR, ekspor.
library;

import 'package:flutter/foundation.dart';

import 'package:hadir/core/attendance_rules.dart';
import 'package:hadir/core/result.dart';
import 'package:hadir/data/dao/attendance_dao.dart';
import 'package:hadir/data/models/attendance.dart';
import 'package:hadir/data/models/office.dart';
import 'package:hadir/data/models/user.dart';
import 'package:hadir/services/admin_service.dart';
import 'package:hadir/services/attendance_service.dart';
import 'package:hadir/services/export_service.dart';
import 'package:hadir/state/settings_provider.dart';

class AdminProvider extends ChangeNotifier {
  final AdminService _admin;
  final AttendanceService _attendance;
  final ExportService _export;
  final SettingsProvider _settings;
  final AttendanceDao _dao;

  User? _user;
  AdminDashboard? _dashboard;
  List<User> _members = const [];
  List<Office> _offices = const [];

  AdminProvider(
    this._admin,
    this._attendance,
    this._export,
    this._settings,
    this._dao,
  );

  User? get user => _user;
  AdminDashboard? get dashboard => _dashboard;
  List<User> get members => _members;
  List<Office> get offices => _offices;

  void attach(User? user) {
    _user = user;
    notifyListeners();
  }

  // ---------------------------------------------------------- dashboard

  Future<AdminDashboard> refreshDashboard() async {
    final d = await _admin.loadDashboard(DateTime.now());
    _dashboard = d;
    notifyListeners();
    return d;
  }

  // ---------------------------------------------------------- anggota

  Future<List<User>> refreshMembers() async {
    _members = await _admin.listMembers();
    notifyListeners();
    return _members;
  }

  Future<Result<User>> addMember({
    required String username,
    required String displayName,
    required String role,
    required String password,
  }) async {
    final r = await _admin.addMember(
      username: username,
      displayName: displayName,
      role: role,
      password: password,
    );
    if (r is Ok<User>) await refreshMembers();
    return r;
  }

  Future<Result<User>> updateMember(User updated) async {
    final acting = _user?.id ?? '';
    final r = await _admin.updateMember(updated, acting);
    if (r is Ok<User>) await refreshMembers();
    return r;
  }

  Future<Result<bool>> resetPassword(String userId, String newPassword) =>
      _admin.resetPassword(userId, newPassword);

  Future<Result<bool>> deleteMember(String userId) async {
    final r = await _admin.deleteMember(userId);
    if (r is Ok<bool>) await refreshMembers();
    return r;
  }

  Future<Map<String, int>> memberMonthlyStats(String userId) =>
      _admin.memberMonthlyStats(userId);

  // ---------------------------------------------------------- kantor

  Future<List<Office>> refreshOffices({bool activeOnly = false}) async {
    _offices = await _admin.listOffices(activeOnly: activeOnly);
    notifyListeners();
    return _offices;
  }

  Future<Result<Office>> saveOffice({
    String? id,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required bool active,
  }) async {
    final r = await _admin.saveOffice(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      active: active,
    );
    if (r is Ok<Office>) await refreshOffices();
    return r;
  }

  Future<Result<bool>> deleteOffice(String officeId) async {
    final r = await _admin.deleteOffice(officeId);
    if (r is Ok<bool>) await refreshOffices();
    return r;
  }

  // ---------------------------------------------------------- rekap

  Future<List<Attendance>> loadRecords({
    required String fromDay,
    required String toDay,
    String? userId,
    String? officeId,
    String? status,
  }) =>
      _dao.queryRecords(
        fromDay: fromDay,
        toDay: toDay,
        userId: userId,
        officeId: officeId,
        status: status,
      );

  /// Update catatan pada sebuah rekaman (coretan admin).
  Future<void> updateRecordNote(String recordId, String? note) async {
    await _attendance.updateNote(recordId, note);
  }

  // ---------------------------------------------------------- manual & QR

  Future<Result<Attendance>> manualMark({
    required String userId,
    required String officeId,
    required DateTime checkIn,
    DateTime? checkOut,
    String? note,
  }) async {
    final r = await _attendance.manualMark(
      userId: userId,
      officeId: officeId,
      checkIn: checkIn,
      checkOut: checkOut,
      note: note,
      settings: _settings.settings,
    );
    return r;
  }

  /// QR absen untuk sebuah kantor dengan jendela waktu tertentu.
  String generateOfficeQr(Office office, int windowSeconds) =>
      _settings.qrCodec.officeToken(
        officeId: office.id,
        windowSeconds: windowSeconds,
      );

  /// Verifikasi QR anggota hasil pindai (untuk absen manual).
  /// Mengembalikan userId + username bila valid.
  ({String userId, String username})? verifyMemberQr(String raw) {
    final data = _settings.qrCodec.parseMemberPayload(raw);
    if (data == null) return null;
    return (userId: data.userId, username: data.username);
  }

  // ---------------------------------------------------------- ekspor

  Future<Result<String>> exportCsv(
    List<Attendance> records,
    String fileName,
  ) =>
      _export.saveCsv(records, fileName);

  /// Pemetaan status → label Indonesia untuk tampilan.
  String statusLabel(String s) => switch (s) {
        'hadir' => 'Hadir',
        'terlambat' => 'Terlambat',
        'pulang_awal' => 'Pulang Awal',
        'lembur' => 'Lembur',
        _ => s,
      };

  String todayKey() => dayKey(DateTime.now());
}
