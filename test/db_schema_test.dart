/// Test skema basis data: tabel, kendala, foreign key, keunikan.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:hadir/core/id_gen.dart';
import 'package:hadir/data/dao/office_dao.dart';
import 'package:hadir/data/dao/user_dao.dart';

import 'helpers.dart';

void main() {
  late Database db;

  setUpAll(() async {
    db = await openTestDb();
  });

  tearDownAll(() async {
    await db.close();
  });

  test('semua tabel & indeks tercipta', () async {
    final baris = await db.rawQuery(
      "SELECT name, type FROM sqlite_master WHERE type IN ('table','index')",
    );
    final nama = baris.map((r) => r['name'] as String).toSet();
    for (final t in ['users', 'offices', 'attendance', 'settings']) {
      expect(nama.contains(t), isTrue, reason: 'tabel $t hilang');
    }
    expect(nama.contains('idx_att_user_day'), isTrue);
  });

  test('seed: admin bawaan + kantor pusat + rahasia QR', () async {
    final users = UserDao(db);
    final admin = await users.findByUsername('ADMIN'); // nocase
    expect(admin, isNotNull);
    expect(admin!.role, 'admin');
    expect(admin.active, isTrue);

    final offices = OfficeDao(db);
    final kantor = await offices.findByName('kantor pusat');
    expect(kantor, isNotNull);
    expect(kantor!.radiusMeters, 150);

    final rahasia = (await db.query(
      'settings',
      where: "key = 'qr_secret'",
    ));
    expect(rahasia.length, 1);
    expect((rahasia.first['value'] as String).length, 64);
  });

  test('CHECK role: nilai asing ditolak', () async {
    expect(
      () => db.insert('users', {
        'id': newId(),
        'username': 'hack${newId()}',
        'display_name': 'x',
        'role': 'superuser',
        'password_hash':
            'pbkdf2-sha256\$1\$abababababababababababababababab\$cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
        'salt': 'abababababababababababababababab',
        'iterations': 1,
        'active': 1,
        'failed_attempts': 0,
        'created_at': 0,
        'updated_at': 0,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('CHECK latitude/longitude di luar rentang ditolak', () async {
    final base = <String, Object?>{
      'id': newId(),
      'name': 'Kantor Kutub ${newId()}',
      'latitude': -6.0,
      'longitude': 106.0,
      'radius_meters': 100,
      'active': 1,
      'created_at': 0,
      'updated_at': 0,
    };
    await expectLater(
      db.insert('offices', {...base, 'latitude': 90.5}),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.insert('offices', {...base, 'longitude': -180.5}),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.insert('offices', {...base, 'radius_meters': 5}),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('UNIQUE username (case-insensitive)', () async {
    final u1 = await buatUser(db, 'budi');
    expect(
      () => buatUser(db, 'BUDI'),
      throwsA(isA<DatabaseException>()),
    );
    // username berbeda tetap boleh
    await buatUser(db, 'budi2');
    expect(u1.username, 'budi');
  });

  test('UNIQUE nama kantor', () async {
    await buatOffice(db, 'Gudang A');
    expect(
      () => buatOffice(db, 'gudang a'),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('foreign key: attendance wajib merujuk user & office nyata', () async {
    final u = await buatUser(db, 'fkuser');
    final o = await buatOffice(db, 'Kantor FK');
    final now = DateTime(2026, 10, 23, 8).millisecondsSinceEpoch;
    final rekaman = <String, Object?>{
      'id': newId(),
      'user_id': u.id,
      'office_id': o.id,
      'day': '2026-10-23',
      'check_in_at': now,
      'check_in_lat': -6.175392,
      'check_in_lng': 106.827153,
      'check_in_distance': 0,
      'check_in_geo_ok': 1,
      'token_ok': 0,
      'status_in': 'tepat',
      'status': 'hadir',
      'method': 'qr',
      'created_at': now,
      'updated_at': now,
    };
    await db.insert('attendance', rekaman);
    await expectLater(
      db.insert('attendance', {...rekaman, 'id': newId(), 'user_id': 'ngasal'}),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      db.insert(
          'attendance', {...rekaman, 'id': newId(), 'office_id': 'ngasal'}),
      throwsA(isA<DatabaseException>()),
    );
    // Hapus user yang punya rekaman → FK mencegah.
    await expectLater(
      db.delete('users', where: 'id = ?', whereArgs: [u.id]),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('UNIQUE (user, day): satu rekaman per pengguna per hari', () async {
    final u = await buatUser(db, 'seharisehari');
    final o = await buatOffice(db, 'Kantor Harian');
    final now = DateTime(2026, 10, 23, 8).millisecondsSinceEpoch;
    final rekaman = <String, Object?>{
      'id': newId(),
      'user_id': u.id,
      'office_id': o.id,
      'day': '2026-10-23',
      'check_in_at': now,
      'check_in_lat': -6.175392,
      'check_in_lng': 106.827153,
      'check_in_distance': 0,
      'check_in_geo_ok': 1,
      'token_ok': 0,
      'status_in': 'tepat',
      'status': 'hadir',
      'method': 'qr',
      'created_at': now,
      'updated_at': now,
    };
    await db.insert('attendance', rekaman);
    await expectLater(
      db.insert('attendance', {...rekaman, 'id': newId()}),
      throwsA(isA<DatabaseException>()),
    );
    // Hari berbeda boleh.
    await db.insert(
      'attendance',
      {...rekaman, 'id': newId(), 'day': '2026-10-24'},
    );
  });

  test('PRAGMA foreign_keys aktif', () async {
    final baris = await db.rawQuery('PRAGMA foreign_keys');
    expect(baris.first.values.first, 1);
  });
}
