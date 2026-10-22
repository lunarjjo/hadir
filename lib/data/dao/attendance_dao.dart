/// DAO rekaman absensi + agregasi statistik.
library;

import 'package:sqflite/sqflite.dart';

import 'package:hadir/data/models/attendance.dart';

class AttendanceDao {
  final Database db;
  AttendanceDao(this.db);

  static const String table = 'attendance';

  Future<void> insert(Attendance record) async {
    await db.insert(table, record.toMap());
  }

  Future<void> updateFull(Attendance record) async {
    await db.update(
      table,
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> updateNote(String id, String? note) async {
    await db.update(
      table,
      {
        'note': note,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Attendance?> findByUserAndDay(String userId, String day) async {
    final rows = await db.query(
      table,
      where: 'user_id = ? AND day = ?',
      whereArgs: [userId, day],
    );
    return rows.isEmpty ? null : Attendance.fromMap(rows.first);
  }

  /// Rekaman terbuka (belum pulang) terbaru dalam [withinHours] jam
  /// terakhir. [now] bisa disuntik untuk pengujian; default jam nyata.
  Future<Attendance?> findLatestOpen(
    String userId, {
    int withinHours = 20,
    DateTime? now,
  }) async {
    final batas =
        (now ?? DateTime.now()).millisecondsSinceEpoch - withinHours * 3600000;
    final rows = await db.query(
      table,
      where: 'user_id = ? AND check_out_at IS NULL AND check_in_at >= ?',
      whereArgs: [userId, batas],
      orderBy: 'check_in_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : Attendance.fromMap(rows.first);
  }

  Future<List<Attendance>> historyByUser(
    String userId, {
    required int fromMs,
    required int toMs,
  }) async {
    final rows = await db.query(
      table,
      where: 'user_id = ? AND check_in_at BETWEEN ? AND ?',
      whereArgs: [userId, fromMs, toMs],
      orderBy: 'check_in_at DESC',
    );
    return rows.map(Attendance.fromMap).toList();
  }

  /// Rekap dengan filter opsional. [fromDay]/[toDay] format YYYY-MM-DD.
  Future<List<Attendance>> queryRecords({
    required String fromDay,
    required String toDay,
    String? userId,
    String? officeId,
    String? status,
  }) async {
    final where = <String>['day BETWEEN ? AND ?'];
    final args = <Object>[fromDay, toDay];
    if (userId != null) {
      where.add('user_id = ?');
      args.add(userId);
    }
    if (officeId != null) {
      where.add('office_id = ?');
      args.add(officeId);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    final rows = await db.query(
      table,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'day DESC, check_in_at DESC',
    );
    return rows.map(Attendance.fromMap).toList();
  }

  /// Jumlah rekaman per status untuk satu hari: {status: jumlah}.
  Future<Map<String, int>> countByStatusOnDay(String day) async {
    final rows = await db.rawQuery(
      'SELECT status, COUNT(*) c FROM $table WHERE day = ? GROUP BY status',
      [day],
    );
    return {for (final r in rows) r['status'] as String: r['c'] as int};
  }

  /// Jumlah pengguna berbeda yang punya rekaman pada satu hari.
  Future<int> distinctUsersOnDay(String day) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(DISTINCT user_id) c FROM $table WHERE day = ?',
      [day],
    );
    return rows.first['c'] as int;
  }

  /// Jumlah rekaman hari itu yang belum absen pulang.
  Future<int> countPendingCheckOutOnDay(String day) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) c FROM $table WHERE day = ? AND check_out_at IS NULL',
      [day],
    );
    return rows.first['c'] as int;
  }

  /// Seri 7 hari: daftar (day, jumlah pengguna hadir).
  Future<List<MapEntry<String, int>>> seriesPerDay(
    String fromDay,
    String toDay,
  ) async {
    final rows = await db.rawQuery(
      'SELECT day, COUNT(DISTINCT user_id) c FROM $table '
      'WHERE day BETWEEN ? AND ? GROUP BY day ORDER BY day',
      [fromDay, toDay],
    );
    return [
      for (final r in rows) MapEntry(r['day'] as String, r['c'] as int),
    ];
  }

  /// Rekap status seorang pengguna dalam rentang hari.
  Future<Map<String, int>> statusCountsForUser(
    String userId,
    String fromDay,
    String toDay,
  ) async {
    final rows = await db.rawQuery(
      'SELECT status, COUNT(*) c FROM $table '
      'WHERE user_id = ? AND day BETWEEN ? AND ? GROUP BY status',
      [userId, fromDay, toDay],
    );
    return {for (final r in rows) r['status'] as String: r['c'] as int};
  }

  Future<int> countForUser(String userId) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) c FROM $table WHERE user_id = ?',
      [userId],
    );
    return rows.first['c'] as int;
  }
}
