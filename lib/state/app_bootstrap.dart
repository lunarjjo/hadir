/// Perakit seluruh dependensi aplikasi (composition root).
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:hadir/data/dao/attendance_dao.dart';
import 'package:hadir/data/dao/setting_dao.dart';
import 'package:hadir/data/db.dart';
import 'package:hadir/services/admin_service.dart';
import 'package:hadir/services/attendance_service.dart';
import 'package:hadir/services/auth_service.dart';
import 'package:hadir/services/export_service.dart';
import 'package:hadir/services/location_service.dart';
import 'package:hadir/state/admin_provider.dart';
import 'package:hadir/state/auth_provider.dart';
import 'package:hadir/state/member_provider.dart';
import 'package:hadir/state/settings_provider.dart';

class AppBootstrap {
  final AppDatabase appDb;
  final Database db;
  final AuthService auth;
  final AttendanceService attendance;
  final AdminService admin;
  final ExportService export;
  final LocationService location;
  final AttendanceDao attendanceDao;
  final AuthProvider authProvider;
  final SettingsProvider settingsProvider;
  final MemberProvider memberProvider;
  final AdminProvider adminProvider;

  AppBootstrap._({
    required this.appDb,
    required this.db,
    required this.auth,
    required this.attendance,
    required this.admin,
    required this.export,
    required this.location,
    required this.attendanceDao,
    required this.authProvider,
    required this.settingsProvider,
    required this.memberProvider,
    required this.adminProvider,
  });

  /// Menyiapkan basis data, service, dan provider.
  ///
  /// [dbFactory]/[dbPath]/[seedAdminPassword] untuk injeksi pengujian.
  static Future<AppBootstrap> init({
    DatabaseFactory? dbFactory,
    String? dbPath,
    String? seedAdminPassword,
  }) async {
    final appDb = AppDatabase(
      factoryOverride: dbFactory,
      dbPath: dbPath,
      seedAdminPassword: seedAdminPassword,
    );
    final db = await appDb.open();

    final prefs = await SharedPreferences.getInstance();
    final settingDao = SettingDao(db);
    final appSettings = await settingDao.loadAppSettings();

    final auth = AuthService(db);
    final attendance = AttendanceService(db);
    final admin = AdminService(db);
    final export = ExportService(db);
    final location = LocationService();
    final attendanceDao = AttendanceDao(db);

    final settingsProvider = SettingsProvider(settingDao, appSettings, prefs);
    final authProvider = AuthProvider(auth);
    final memberProvider = MemberProvider(
      attendance,
      settingsProvider,
      attendanceDao,
    );
    final adminProvider = AdminProvider(
      admin,
      attendance,
      export,
      settingsProvider,
      attendanceDao,
    );

    authProvider.onUserChanged = (user) {
      memberProvider.attach(user);
      adminProvider.attach(user);
    };

    return AppBootstrap._(
      appDb: appDb,
      db: db,
      auth: auth,
      attendance: attendance,
      admin: admin,
      export: export,
      location: location,
      attendanceDao: attendanceDao,
      authProvider: authProvider,
      settingsProvider: settingsProvider,
      memberProvider: memberProvider,
      adminProvider: adminProvider,
    );
  }

  @visibleForTesting
  Future<void> close() => appDb.close();
}
