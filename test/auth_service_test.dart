/// Test AuthService: login, lockout, sesi, ganti sandi/nama.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:hadir/core/result.dart';
import 'package:hadir/services/auth_service.dart';

import 'helpers.dart';

void main() {
  late Database db;
  late AuthService auth;
  var waktu = DateTime(2026, 10, 23, 8, 0, 0);
  DateTime clock() => waktu;

  setUpAll(() async {
    db = await openTestDb(clock: clock);
    auth = AuthService(db, clock: clock);
    await buatUser(db, 'budi', sandi: 'sandibudi');
    await buatUser(db, 'nonaktif', aktif: false);
  });

  tearDownAll(() => db.close());

  void maju(Duration d) => waktu = waktu.add(d);

  group('login', () {
    test('berhasil: kredensial benar (username case-insensitive)', () async {
      final r = await auth.login('BUDI', 'sandibudi');
      expect(r, isA<Ok>());
      await auth.logout();
    });

    test('gagal: sandi salah / user tidak ada (pesan sama)', () async {
      final a = await auth.login('budi', 'salah');
      final b = await auth.login('tidakada', 'apa');
      final ga = (a as Err).error;
      final gb = (b as Err).error;
      expect(ga.code, AppErrCode.invalidCredentials);
      expect(gb.code, AppErrCode.invalidCredentials);
    });

    test('gagal: akun nonaktif', () async {
      final r = await auth.login('nonaktif', 'sandirahasia');
      expect((r as Err).error.code, AppErrCode.inactive);
    });
  });

  group('lockout', () {
    test('5 kali gagal → terkunci 15 menit, bahkan dengan sandi benar', () async {
      await buatUser(db, 'korbanlock', sandi: 'rahasia');
      for (var i = 0; i < 5; i++) {
        await auth.login('korbanlock', 'salah$i');
      }
      final r = await auth.login('korbanlock', 'rahasia');
      final galat = (r as Err).error;
      expect(galat.code, AppErrCode.locked);
      expect(galat.params['menit'], greaterThanOrEqualTo(14));
    });

    test('setelah 15 menit bisa login lagi & hitungan reset', () async {
      maju(const Duration(minutes: 16));
      final r = await auth.login('korbanlock', 'rahasia');
      expect(r, isA<Ok>());
      // Gagal sekali lagi tidak langsung mengunci.
      await auth.logout();
      await auth.login('korbanlock', 'salah');
      final r2 = await auth.login('korbanlock', 'rahasia');
      expect(r2, isA<Ok>());
      await auth.logout();
    });

    test('hitungan gagal reset saat sukses', () async {
      await buatUser(db, 'resetcount', sandi: 'rahasia');
      for (var i = 0; i < 4; i++) {
        await auth.login('resetcount', 'salah');
      }
      await auth.login('resetcount', 'rahasia');
      await auth.logout();
      for (var i = 0; i < 4; i++) {
        await auth.login('resetcount', 'salah');
      }
      // Masih belum terkunci (hitungan mulai dari 0 lagi setelah sukses).
      final r = await auth.login('resetcount', 'rahasia');
      expect(r, isA<Ok>());
      await auth.logout();
    });
  });

  group('sesi', () {
    test('restore: valid → user; kedaluwarsa → hapus', () async {
      await auth.login('budi', 'sandibudi');
      final r1 = await auth.restoreSession();
      expect(r1, isA<Ok>());
      expect((r1 as Ok).value.username, 'budi');

      maju(const Duration(hours: 12, seconds: 1));
      final r2 = await auth.restoreSession();
      expect(r2, isA<Err>());

      // Sesi terhapus → login ulang bersih.
      final r3 = await auth.login('budi', 'sandibudi');
      expect(r3, isA<Ok>());
    });

    test('ingat saya: sesi 30 hari', () async {
      await auth.logout();
      await auth.login('budi', 'sandibudi', rememberMe: true);
      maju(const Duration(days: 29));
      expect(await auth.restoreSession(), isA<Ok>());
      await auth.logout();
    });

    test('logout menghapus sesi', () async {
      await auth.login('budi', 'sandibudi');
      await auth.logout();
      expect(await auth.restoreSession(), isA<Err>());
    });
  });

  group('ganti sandi & nama', () {
    test('ganti sandi: sandi lama salah → tolak; benar → berlaku', () async {
      final budi = (await auth.login('budi', 'sandibudi')) as Ok;
      final userId = budi.value.userId;
      await auth.logout();

      final gagal = await auth.changePassword(userId, 'salah', 'sandiBaru1');
      expect((gagal as Err).error.code, AppErrCode.invalidCredentials);

      final sukses = await auth.changePassword(userId, 'sandibudi', 'sandiBaru1');
      expect(sukses, isA<Ok>());

      final loginLama = await auth.login('budi', 'sandibudi');
      expect(loginLama, isA<Err>());
      final loginBaru = await auth.login('budi', 'sandiBaru1');
      expect(loginBaru, isA<Ok>());
      await auth.logout();
    });

    test('ganti nama tampilan', () async {
      final r = await auth.login('budi', 'sandiBaru1');
      final userId = (r as Ok).value.userId;
      final ganti = await auth.changeDisplayName(userId, 'Budi Santoso');
      expect((ganti as Ok).value.displayName, 'Budi Santoso');
      final cek = await auth.restoreSession();
      expect((cek as Ok).value.displayName, 'Budi Santoso');
      await auth.logout();
    });
  });
}
