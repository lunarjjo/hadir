/// DAO settings (key-value) + pemuat AppSettings.
library;

import 'package:sqflite/sqflite.dart';

import 'package:hadir/core/crypto.dart';
import 'package:hadir/data/models/app_settings.dart';

class SettingDao {
  final Database db;
  SettingDao(this.db);

  static const String table = 'settings';

  Future<String?> get(String key) async {
    final rows = await db.query(
      table,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> set(String key, String value) async {
    await db.insert(
      table,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String key) async {
    await db.delete(table, where: 'key = ?', whereArgs: [key]);
  }

  Future<int> getInt(String key, int defaultValue) async {
    final raw = await get(key);
    return int.tryParse(raw ?? '') ?? defaultValue;
  }

  Future<bool> getBool(String key, bool defaultValue) async {
    final raw = await get(key);
    if (raw == '1') return true;
    if (raw == '0') return false;
    return defaultValue;
  }

  /// Muat [AppSettings]; rahasia QR dibuat & disimpan bila belum ada.
  Future<AppSettings> loadAppSettings() async {
    var secret = await get('qr_secret');
    if (secret == null || secret.length < 32) {
      secret = randomHex(32);
      await set('qr_secret', secret);
    }
    return AppSettings(
      qrSecretHex: secret,
      workStartMinutes: await getInt('work_start', 480),
      workEndMinutes: await getInt('work_end', 1020),
      lateGraceMinutes: await getInt('late_grace', 15),
      earlyLeaveGraceMinutes: await getInt('early_grace', 15),
      overtimeExtraMinutes: await getInt('overtime_extra', 30),
      requireQr: await getBool('require_qr', true),
      qrWindowSeconds: await getInt('qr_window', 300),
      verifyCheckOutGeo: await getBool('verify_checkout_geo', true),
    );
  }

  Future<void> saveAppSettings(AppSettings s) async {
    await set('work_start', s.workStartMinutes.toString());
    await set('work_end', s.workEndMinutes.toString());
    await set('late_grace', s.lateGraceMinutes.toString());
    await set('early_grace', s.earlyLeaveGraceMinutes.toString());
    await set('overtime_extra', s.overtimeExtraMinutes.toString());
    await set('require_qr', s.requireQr ? '1' : '0');
    await set('qr_window', s.qrWindowSeconds.toString());
    await set('verify_checkout_geo', s.verifyCheckOutGeo ? '1' : '0');
  }
}
