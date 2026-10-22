/// Operasi admin: kelola anggota & kantor, statistik dashboard.
library;

import 'package:sqflite/sqflite.dart';

import 'package:hadir/core/attendance_rules.dart';
import 'package:hadir/core/crypto.dart';
import 'package:hadir/core/id_gen.dart';
import 'package:hadir/core/result.dart';
import 'package:hadir/core/validation.dart';
import 'package:hadir/data/dao/attendance_dao.dart';
import 'package:hadir/data/dao/office_dao.dart';
import 'package:hadir/data/dao/user_dao.dart';
import 'package:hadir/data/models/office.dart';
import 'package:hadir/data/models/user.dart';

/// Ringkasan satu hari untuk dashboard admin.
class AdminDashboard {
  final int totalAnggota;
  final int hadir;
  final int terlambat;
  final int pulangAwal;
  final int lembur;
  final int belumPulang;
  final int tidakHadir;

  /// Seri 7 hari (terlama → terbaru): kunci hari → jumlah hadir.
  final List<MapEntry<String, int>> minggu;

  const AdminDashboard({
    required this.totalAnggota,
    required this.hadir,
    required this.terlambat,
    required this.pulangAwal,
    required this.lembur,
    required this.belumPulang,
    required this.tidakHadir,
    required this.minggu,
  });

  int get totalRekaman => hadir + terlambat + pulangAwal + lembur;
}

class AdminService {
  final DateTime Function() _clock;
  final UserDao _users;
  final OfficeDao _offices;
  final AttendanceDao _att;

  AdminService(Database db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _users = UserDao(db),
        _offices = OfficeDao(db),
        _att = AttendanceDao(db);

  // ------------------------------------------------------------ anggota

  Future<Result<User>> addMember({
    required String username,
    required String displayName,
    required String role,
    required String password,
  }) async {
    final uname = username.trim().toLowerCase();
    if (validateUsername(uname) != null) return err(AppErrCode.validation);
    if (validateDisplayName(displayName) != null) {
      return err(AppErrCode.validation);
    }
    if (validatePassword(password) != null) return err(AppErrCode.validation);
    if (role != 'admin' && role != 'member') return err(AppErrCode.validation);
    if (await _users.findByUsername(uname) != null) {
      return err(AppErrCode.usernameTaken);
    }
    final nowMs = _clock().millisecondsSinceEpoch;
    final user = User(
      id: newId(),
      username: uname,
      displayName: displayName.trim(),
      role: role,
      active: true,
      failedAttempts: 0,
      lockedUntilMs: null,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
    );
    await _users.insert(user, hashPassword(password));
    return ok(user);
  }

  /// Perbarui profil anggota; [actingAdminId] untuk penjaga diri sendiri
  /// dan admin terakhir.
  Future<Result<User>> updateMember(User updated, String actingAdminId) async {
    final current = await _users.findById(updated.id);
    if (current == null) return err(AppErrCode.notFound);

    final menurunkanAdmin =
        current.isAdmin && (updated.role != 'admin' || !updated.active);
    if (menurunkanAdmin) {
      if (updated.id == actingAdminId) return err(AppErrCode.selfTarget);
      final adminAktif = await _users.countActiveAdmins();
      if (adminAktif <= 1) return err(AppErrCode.lastAdmin);
    }

    final safe = updated.copyWith(
      updatedAtMs: _clock().millisecondsSinceEpoch,
    );
    await _users.updateProfile(safe);
    return ok(safe);
  }

  Future<Result<bool>> resetPassword(String userId, String newPassword) async {
    if (validatePassword(newPassword) != null) {
      return err(AppErrCode.validation);
    }
    final user = await _users.findById(userId);
    if (user == null) return err(AppErrCode.notFound);
    await _users.updatePassword(userId, hashPassword(newPassword));
    return ok(true);
  }

  Future<Result<bool>> deleteMember(String userId) async {
    final user = await _users.findById(userId);
    if (user == null) return err(AppErrCode.notFound);
    if (await _att.countForUser(userId) > 0) {
      return err(AppErrCode.hasAttendance);
    }
    await _users.delete(userId);
    return ok(true);
  }

  Future<List<User>> listMembers() => _users.listAll();

  Future<Map<String, int>> memberMonthlyStats(String userId) async {
    final now = _clock();
    final awal = DateTime(now.year, now.month, 1);
    final akhir = DateTime(now.year, now.month + 1, 0);
    return _att.statusCountsForUser(userId, dayKey(awal), dayKey(akhir));
  }

  // ------------------------------------------------------------ kantor

  Future<Result<Office>> saveOffice({
    String? id,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required bool active,
  }) async {
    if (validateOfficeName(name) != null) return err(AppErrCode.validation);
    if (latitude < -90 || latitude > 90) return err(AppErrCode.validation);
    if (longitude < -180 || longitude > 180) return err(AppErrCode.validation);
    if (radiusMeters < 10 || radiusMeters > 5000) {
      return err(AppErrCode.validation);
    }
    final bentrok = await _offices.findByName(name.trim());
    if (bentrok != null && bentrok.id != id) {
      return err(AppErrCode.officeNameTaken);
    }
    final nowMs = _clock().millisecondsSinceEpoch;
    if (id == null) {
      final office = Office(
        id: newId(),
        name: name.trim(),
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        active: active,
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      );
      await _offices.insert(office);
      return ok(office);
    }
    final existing = await _offices.findById(id);
    if (existing == null) return err(AppErrCode.notFound);
    final updated = existing.copyWith(
      name: name.trim(),
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      active: active,
      updatedAtMs: nowMs,
    );
    await _offices.update(updated);
    return ok(updated);
  }

  Future<Result<bool>> deleteOffice(String officeId) async {
    final office = await _offices.findById(officeId);
    if (office == null) return err(AppErrCode.notFound);
    if (await _offices.countAttendance(officeId) > 0) {
      return err(AppErrCode.hasAttendance);
    }
    await _offices.delete(officeId);
    return ok(true);
  }

  Future<List<Office>> listOffices({bool activeOnly = false}) =>
      _offices.list(activeOnly: activeOnly);

  // ------------------------------------------------------------ dashboard

  Future<AdminDashboard> loadDashboard(DateTime day) async {
    final kunci = dayKey(day);
    final totalAnggota = await _users.countActiveMembers();
    final perStatus = await _att.countByStatusOnDay(kunci);
    final hadirUser = await _att.distinctUsersOnDay(kunci);
    final belumPulang = await _att.countPendingCheckOutOnDay(kunci);

    // Seri 7 hari berakhir hari ini.
    final seri = await _att.seriesPerDay(
      dayKey(day.subtract(const Duration(days: 6))),
      kunci,
    );
    final peta = Map.fromEntries(seri);
    final minggu = <MapEntry<String, int>>[];
    for (var i = 6; i >= 0; i--) {
      final d = day.subtract(Duration(days: i));
      final k = dayKey(d);
      minggu.add(MapEntry(k, peta[k] ?? 0));
    }

    return AdminDashboard(
      totalAnggota: totalAnggota,
      hadir: (perStatus['hadir'] ?? 0) + (perStatus['lembur'] ?? 0),
      terlambat: perStatus['terlambat'] ?? 0,
      pulangAwal: perStatus['pulang_awal'] ?? 0,
      lembur: perStatus['lembur'] ?? 0,
      belumPulang: belumPulang,
      tidakHadir: totalAnggota - hadirUser < 0 ? 0 : totalAnggota - hadirUser,
      minggu: minggu,
    );
  }
}
