/// Isi awal basis data: rahasia QR, admin bawaan, kantor contoh.
library;

import 'package:sqflite/sqflite.dart';

import 'package:hadir/core/crypto.dart';
import 'package:hadir/core/id_gen.dart';
import 'package:hadir/data/dao/office_dao.dart';
import 'package:hadir/data/dao/setting_dao.dart';
import 'package:hadir/data/dao/user_dao.dart';
import 'package:hadir/data/models/office.dart';
import 'package:hadir/data/models/user.dart';

class DatabaseSeeder {
  final Database db;
  final DateTime Function() clock;
  final String adminUsername;
  final String adminPassword;

  DatabaseSeeder(
    this.db, {
    DateTime Function()? clock,
    this.adminUsername = 'admin',
    this.adminPassword = 'admin123',
  }) : clock = clock ?? DateTime.now;

  /// Idempoten: hanya mengisi tabel yang masih kosong.
  Future<void> seed() async {
    final settings = SettingDao(db);
    // loadAppSettings sekaligus membuat rahasia QR bila belum ada.
    await settings.loadAppSettings();

    final users = UserDao(db);
    if (await users.countAll() == 0) {
      final now = clock().millisecondsSinceEpoch;
      await users.insert(
        User(
          id: newId(),
          username: adminUsername.trim().toLowerCase(),
          displayName: 'Administrator',
          role: 'admin',
          active: true,
          failedAttempts: 0,
          lockedUntilMs: null,
          createdAtMs: now,
          updatedAtMs: now,
        ),
        hashPassword(adminPassword),
      );
    }

    final offices = OfficeDao(db);
    if (await offices.countAll() == 0) {
      final now = clock().millisecondsSinceEpoch;
      await offices.insert(
        Office(
          id: newId(),
          name: 'Kantor Pusat',
          latitude: -6.175392,
          longitude: 106.827153,
          radiusMeters: 150,
          active: true,
          createdAtMs: now,
          updatedAtMs: now,
        ),
      );
    }
  }
}
