/// DAO pengguna.
library;

import 'package:sqflite/sqflite.dart';

import 'package:hadir/core/crypto.dart';
import 'package:hadir/data/models/user.dart';

class UserDao {
  final Database db;
  UserDao(this.db);

  static const String table = 'users';

  Future<User?> findById(String id) async {
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<User?> findByUsername(String username) async {
    final rows = await db.query(
      table,
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<UserSecret?> findSecret(String userId) async {
    final rows = await db.query(
      table,
      columns: ['id', 'password_hash'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserSecret(
      userId: userId,
      encoded: rows.first['password_hash'] as String,
    );
  }

  Future<void> insert(User user, PasswordHash hash) async {
    await db.insert(table, {
      ...user.toMap(),
      'password_hash': hash.encode(),
      'salt': hash.saltHex,
      'iterations': hash.iterations,
    });
  }

  Future<void> updateProfile(User user) async {
    await db.update(
      table,
      {
        'display_name': user.displayName,
        'role': user.role,
        'active': user.active ? 1 : 0,
        'updated_at': user.updatedAtMs,
      },
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<void> updatePassword(String userId, PasswordHash hash) async {
    await db.update(
      table,
      {
        'password_hash': hash.encode(),
        'salt': hash.saltHex,
        'iterations': hash.iterations,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> updateLoginState(
    String userId,
    int failedAttempts,
    int? lockedUntilMs,
  ) async {
    await db.update(
      table,
      {
        'failed_attempts': failedAttempts,
        'locked_until': lockedUntilMs,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<List<User>> listAll() async {
    final rows = await db.query(table, orderBy: 'display_name COLLATE NOCASE');
    return rows.map(User.fromMap).toList();
  }

  Future<int> countAll() async {
    final rows = await db.rawQuery('SELECT COUNT(*) c FROM $table');
    return rows.first['c'] as int;
  }

  Future<int> countActiveMembers() async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) c FROM $table WHERE role = ? AND active = 1',
      ['member'],
    );
    return rows.first['c'] as int;
  }

  Future<int> countActiveAdmins() async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) c FROM $table WHERE role = ? AND active = 1',
      ['admin'],
    );
    return rows.first['c'] as int;
  }

  Future<void> delete(String userId) async {
    await db.delete(table, where: 'id = ?', whereArgs: [userId]);
  }
}
