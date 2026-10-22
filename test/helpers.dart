/// Util bersama test: basis data FFI + seed + pabrik data uji.
library;

import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hadir/core/crypto.dart';
import 'package:hadir/core/id_gen.dart';
import 'package:hadir/data/dao/office_dao.dart';
import 'package:hadir/data/dao/user_dao.dart';
import 'package:hadir/data/models/office.dart';
import 'package:hadir/data/models/user.dart';
import 'package:hadir/data/db.dart';

/// Buka DB uji (berkas sementara unik per panggilan, SQLite via FFI).
Future<Database> openTestDb({
  DateTime Function()? clock,
  String? adminPassword,
}) async {
  sqfliteFfiInit();
  final dir = await Directory.systemTemp.createTemp('hadir-test');
  final db = AppDatabase(
    factoryOverride: databaseFactoryFfi,
    dbPath: '${dir.path}/test.db',
    clock: clock,
    seedAdminPassword: adminPassword ?? 'admin123',
  );
  return db.open();
}

Future<User> buatUser(
  Database db,
  String username, {
  String role = 'member',
  bool aktif = true,
  String sandi = 'sandirahasia',
}) async {
  final now = DateTime(2026, 10, 23).millisecondsSinceEpoch;
  final u = User(
    id: newId(),
    username: username,
    displayName: 'Nama $username',
    role: role,
    active: aktif,
    failedAttempts: 0,
    lockedUntilMs: null,
    createdAtMs: now,
    updatedAtMs: now,
  );
  await UserDao(db).insert(u, hashPassword(sandi));
  return u;
}

Future<Office> buatOffice(Database db, String nama) async {
  final now = DateTime(2026, 10, 23).millisecondsSinceEpoch;
  final o = Office(
    id: newId(),
    name: nama,
    latitude: -6.175392,
    longitude: 106.827153,
    radiusMeters: 150,
    active: true,
    createdAtMs: now,
    updatedAtMs: now,
  );
  await OfficeDao(db).insert(o);
  return o;
}
