/// Test DAO user & kantor: CRUD, pencarian, agregasi.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:hadir/core/crypto.dart';
import 'package:hadir/data/dao/office_dao.dart';
import 'package:hadir/data/dao/user_dao.dart';
import 'package:hadir/data/models/office.dart';
import 'package:hadir/data/models/user.dart';

import 'helpers.dart';

void main() {
  late Database db;
  late UserDao users;
  late OfficeDao offices;

  setUpAll(() async {
    db = await openTestDb();
    users = UserDao(db);
    offices = OfficeDao(db);
  });

  tearDownAll(() => db.close());

  group('UserDao', () {
    test('insert → findById / findByUsername (nocase) / listAll', () async {
      final u = await buatUser(db, 'caritest');
      final byId = await users.findById(u.id);
      expect(byId?.username, 'caritest');
      final byName = await users.findByUsername('CARITEST');
      expect(byName?.id, u.id);
      final byName2 = await users.findByUsername('tidakada');
      expect(byName2, isNull);
      final semua = await users.listAll();
      expect(semua.length, greaterThanOrEqualTo(2)); // admin + caritest
    });

    test('findSecret mengembalikan hash terenkode', () async {
      final u = await buatUser(db, 'rahasiatest');
      final s = await users.findSecret(u.id);
      expect(s, isNotNull);
      expect(s!.encoded.startsWith('pbkdf2-sha256\$'), isTrue);
      expect(verifyPassword('sandirahasia', s.encoded), isTrue);
    });

    test('updateProfile mengubah nama/peran/aktif', () async {
      final u = await buatUser(db, 'updatetest');
      final baru = u.copyWith(
        displayName: 'Nama Baru',
        role: 'admin',
        active: false,
        updatedAtMs: 999,
      );
      await users.updateProfile(baru);
      final hasil = await users.findById(u.id);
      expect(hasil?.displayName, 'Nama Baru');
      expect(hasil?.role, 'admin');
      expect(hasil?.active, isFalse);
      expect(hasil?.failedAttempts, u.failedAttempts); // tak tersentuh
    });

    test('updatePassword → verifikasi sandi baru', () async {
      final u = await buatUser(db, 'gantisandi');
      await users.updatePassword(u.id, hashPassword('sandiBaru99'));
      final s = await users.findSecret(u.id);
      expect(verifyPassword('sandiBaru99', s!.encoded), isTrue);
      expect(verifyPassword('sandirahasia', s.encoded), isFalse);
    });

    test('updateLoginState mencatat percobaan & kunci', () async {
      final u = await buatUser(db, 'lockstate');
      await users.updateLoginState(u.id, 3, null);
      expect((await users.findById(u.id))?.failedAttempts, 3);
      await users.updateLoginState(u.id, 0, 12345);
      final hasil = await users.findById(u.id);
      expect(hasil?.failedAttempts, 0);
      expect(hasil?.lockedUntilMs, 12345);
    });

    test('hitung: countAll / countActiveMembers / countActiveAdmins', () async {
      final awal = await users.countAll();
      await buatUser(db, 'memberA');
      await buatUser(db, 'memberB');
      final adminTambahan = await buatUser(db, 'adminB', role: 'admin');
      expect(await users.countAll(), awal + 3);
      expect(
        await users.countActiveMembers(),
        greaterThanOrEqualTo(2),
      );
      expect(await users.countActiveAdmins(), greaterThanOrEqualTo(2));
      await users.updateProfile(adminTambahan.copyWith(active: false));
      expect(
        await users.countActiveAdmins(),
        lessThan(await users.countAll()),
      );
    });

    test('delete menghapus baris', () async {
      final u = await buatUser(db, 'hapusku');
      await users.delete(u.id);
      expect(await users.findById(u.id), isNull);
    });
  });

  group('OfficeDao', () {
    test('insert → list (urut nama) / findById / findByName nocase', () async {
      final a = await buatOffice(db, 'Kantor Alpha');
      final b = await buatOffice(db, 'Kantor Beta');
      final semua = await offices.list();
      final idxA = semua.indexWhere((o) => o.id == a.id);
      final idxB = semua.indexWhere((o) => o.id == b.id);
      expect(idxA, lessThan(idxB)); // Alpha < Beta (urut nama)
      expect(await offices.findByName('kantor beta'), isNotNull);
      final ditemukan = await offices.findByName('kantor beta');
      expect(ditemukan?.id, b.id);
      expect(await offices.findById(a.id), isNotNull);

      final nonaktif = a.copyWith(active: false);
      await offices.update(nonaktif);
      final aktifSaja = await offices.list(activeOnly: true);
      expect(aktifSaja.where((o) => o.id == a.id), isEmpty);
      expect(aktifSaja.where((o) => o.id == b.id), isNotEmpty);
    });

    test('setActive memindahkan status', () async {
      final o = await buatOffice(db, 'Kantor Toggle');
      await offices.setActive(o.id, false);
      expect((await offices.findById(o.id))?.active, isFalse);
      await offices.setActive(o.id, true);
      expect((await offices.findById(o.id))?.active, isTrue);
    });

    test('countAttendance terhadap rekaman', () async {
      final o = await buatOffice(db, 'Kantor Hitung');
      expect(await offices.countAttendance(o.id), 0);
      final u = await buatUser(db, 'penghitung');
      final now = DateTime(2026, 10, 23, 8).millisecondsSinceEpoch;
      await db.insert('attendance', {
        'id': 'att-hitung-1',
        'user_id': u.id,
        'office_id': o.id,
        'day': '2026-10-23',
        'check_in_at': now,
        'check_in_lat': -6.0,
        'check_in_lng': 106.0,
        'check_in_distance': 0,
        'check_in_geo_ok': 1,
        'token_ok': 0,
        'status_in': 'tepat',
        'status': 'hadir',
        'method': 'qr',
        'created_at': now,
        'updated_at': now,
      });
      expect(await offices.countAttendance(o.id), 1);
    });

    test('delete kantor tanpa rekaman berhasil', () async {
      final o = await buatOffice(db, 'Kantor Musim');
      await offices.delete(o.id);
      expect(await offices.findById(o.id), isNull);
    });
  });

  test('model Office.fromMap/toMap bolak-balik', () async {
    final m = <String, Object?>{
      'id': 'o1',
      'name': 'Kantor',
      'latitude': -6.5,
      'longitude': 106.5,
      'radius_meters': 200,
      'active': 1,
      'created_at': 1,
      'updated_at': 2,
    };
    final o = Office.fromMap(m);
    expect(o.toMap(), m);
  });

  test('model User.fromMap/toMap bolak-balik', () async {
    final m = <String, Object?>{
      'id': 'u1',
      'username': 'budi',
      'display_name': 'Budi',
      'role': 'member',
      'active': 1,
      'failed_attempts': 2,
      'locked_until': null,
      'created_at': 1,
      'updated_at': 2,
    };
    final u = User.fromMap(m);
    expect(u.toMap(), m);
    expect(u.isAdmin, isFalse);
  });
}
