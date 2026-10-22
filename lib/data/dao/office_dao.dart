/// DAO kantor.
library;

import 'package:sqflite/sqflite.dart';

import 'package:hadir/data/models/office.dart';

class OfficeDao {
  final Database db;
  OfficeDao(this.db);

  static const String table = 'offices';

  Future<List<Office>> list({bool activeOnly = false}) async {
    final rows = await db.query(
      table,
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Office.fromMap).toList();
  }

  Future<Office?> findById(String id) async {
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Office.fromMap(rows.first);
  }

  Future<Office?> findByName(String name) async {
    final rows = await db.query(
      table,
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name],
      limit: 1,
    );
    return rows.isEmpty ? null : Office.fromMap(rows.first);
  }

  Future<void> insert(Office office) async {
    await db.insert(table, office.toMap());
  }

  Future<void> update(Office office) async {
    await db.update(
      table,
      office.toMap(),
      where: 'id = ?',
      whereArgs: [office.id],
    );
  }

  Future<void> setActive(String id, bool active) async {
    await db.update(
      table,
      {
        'active': active ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countAll() async {
    final rows = await db.rawQuery('SELECT COUNT(*) c FROM $table');
    return rows.first['c'] as int;
  }

  /// Jumlah rekaman absensi yang merujuk kantor ini (untuk penjaga hapus).
  Future<int> countAttendance(String officeId) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) c FROM attendance WHERE office_id = ?',
      [officeId],
    );
    return rows.first['c'] as int;
  }
}
