/// Test AttendanceService: alur masuk/pulang, geofence, token, manual.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:hadir/core/attendance_rules.dart';
import 'package:hadir/core/qr_token.dart';
import 'package:hadir/core/result.dart';
import 'package:hadir/data/dao/office_dao.dart';
import 'package:hadir/data/dao/setting_dao.dart';
import 'package:hadir/data/models/app_settings.dart';
import 'package:hadir/data/models/attendance.dart';
import 'package:hadir/data/models/office.dart';
import 'package:hadir/services/attendance_service.dart';

import 'helpers.dart';

void main() {
  late Database db;
  late AttendanceService svc;
  late String budi;
  late Office kantor;
  var waktu = DateTime(2026, 10, 23, 8, 0, 0);
  DateTime clock() => waktu;
  const rahasia = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  setUpAll(() async {
    db = await openTestDb(clock: clock);
    svc = AttendanceService(db, clock: clock);
    budi = (await buatUser(db, 'budikerja')).id;
    final offices = await OfficeDao(db).list();
    kantor = offices.first;
  });

  tearDownAll(() => db.close());

  void maju(Duration d) => waktu = waktu.add(d);

  AppSettings pengaturan({bool wajibQr = false}) => AppSettings(
        qrSecretHex: rahasia,
        requireQr: wajibQr,
      );

  String token({int window = 300, int menitMaju = 0}) => QrCodec(
        secretHex: rahasia,
        clock: () => waktu.add(Duration(minutes: menitMaju)),
      ).officeToken(officeId: kantor.id, windowSeconds: window);

  // Koordinat: pusat kantor (Monas) & ~600 m ke utara.
  const latPusat = -6.175392, lngPusat = 106.827153;
  const latJauh = -6.1699, lngJauh = 106.827153;

  group('checkIn', () {
    test('sukses: di kantor, 08:00 → tepat', () async {
      final r = await svc.checkIn(
        userId: budi,
        office: kantor,
        lat: latPusat,
        lng: lngPusat,
        settings: pengaturan(),
      );
      expect(r, isA<Ok>());
      final rek = (r as Ok).value;
      expect(rek.statusIn, CheckInStatus.tepat);
      expect(rek.status, 'hadir');
      expect(rek.checkInGeoOk, isTrue);
      expect(rek.day, '2026-10-23');
    });

    test('duplikat ditolak', () async {
      final r = await svc.checkIn(
        userId: budi,
        office: kantor,
        lat: latPusat,
        lng: lngPusat,
        settings: pengaturan(),
      );
      expect((r as Err).error.code, AppErrCode.alreadyCheckedIn);
    });

    test('di luar radius → ditolak dengan jarak', () async {
      await buatUser(db, 'siJauh');
      final siJauh = (await (db).query('users',
              where: "username = 'siJauh'"))
          .first['id'] as String;
      final r = await svc.checkIn(
        userId: siJauh,
        office: kantor,
        lat: latJauh,
        lng: lngJauh,
        settings: pengaturan(),
      );
      final galat = (r as Err).error;
      expect(galat.code, AppErrCode.outsideRadius);
      expect(galat.params['jarak'], contains('m'));
      expect(galat.params['nama'], 'Kantor Pusat');
    });

    test('pukul 10:00 → terlambat', () async {
      await buatUser(db, 'siTelat');
      final siTelat = (await db
              .query('users', where: "username = 'siTelat'"))
          .first['id'] as String;
      maju(const Duration(hours: 2)); // 10:00
      final r = await svc.checkIn(
        userId: siTelat,
        office: kantor,
        lat: latPusat,
        lng: lngPusat,
        settings: pengaturan(),
      );
      expect((r as Ok).value.status, 'terlambat');
    });

    test('wajib QR: tanpa token → needToken; token salah → badToken', () async {
      await buatUser(db, 'siQr');
      final siQr = (await db.query('users', where: "username = 'siQr'"))
          .first['id'] as String;
      final r1 = await svc.checkIn(
        userId: siQr,
        office: kantor,
        lat: latPusat,
        lng: lngPusat,
        settings: pengaturan(wajibQr: true),
      );
      final g1 = (r1 as Err).error;
      expect(g1.code, AppErrCode.needToken);

      final r2 = await svc.checkIn(
        userId: siQr,
        office: kantor,
        lat: latPusat,
        lng: lngPusat,
        tokenRaw: 'HADIR|T|xxx|0|60|abababababababababababababababab',
        settings: pengaturan(wajibQr: true),
      );
      expect((r2 as Err).error.code, AppErrCode.badToken);
    });

    test('wajib QR: token benar → sukses, tokenOk tercatat', () async {
      await buatUser(db, 'siQrOk');
      final siQrOk = (await db.query('users', where: "username = 'siQrOk'"))
          .first['id'] as String;
      final r = await svc.checkIn(
        userId: siQrOk,
        office: kantor,
        lat: latPusat,
        lng: lngPusat,
        tokenRaw: token(),
        settings: pengaturan(wajibQr: true),
      );
      expect(r, isA<Ok>());
      expect((r as Ok).value.tokenOk, isTrue);
    });

    test('token kantor lain → officeMismatch', () async {
      await buatUser(db, 'siTokenLain');
      final siTokenLain =
          (await db.query('users', where: "username = 'siTokenLain'"))
              .first['id'] as String;
      final tokenLain = QrCodec(secretHex: rahasia, clock: clock)
          .officeToken(officeId: 'kantor-lain', windowSeconds: 300);
      final r = await svc.checkIn(
        userId: siTokenLain,
        office: kantor,
        lat: latPusat,
        lng: lngPusat,
        tokenRaw: tokenLain,
        settings: pengaturan(wajibQr: true),
      );
      expect((r as Err).error.code, AppErrCode.tokenOfficeMismatch);
    });
  });

  group('checkOut', () {
    test('tanpa rekaman terbuka → noOpenRecord', () async {
      await buatUser(db, 'belumMasuk');
      final belumMasuk =
          (await db.query('users', where: "username = 'belumMasuk'"))
              .first['id'] as String;
      final r = await svc.checkOut(
        userId: belumMasuk,
        lat: latPusat,
        lng: lngPusat,
        settings: pengaturan(),
      );
      expect((r as Err).error.code, AppErrCode.noOpenRecord);
    });

    test('sukses di 17:00 → tepat; duplikat → sudah pulang', () async {
      // budi absen masuk 08:00 (grup sebelumnya).
      waktu = DateTime(2026, 10, 23, 17, 0); // tepat jam pulang
      final r = await svc.checkOut(
        userId: budi,
        lat: latPusat,
        lng: lngPusat,
        settings: pengaturan(),
      );
      expect(r, isA<Ok>());
      final rek = (r as Ok).value;
      expect(rek.statusOut, CheckOutStatus.tepat);
      expect(rek.status, 'hadir');
      expect(rek.workedMinutes, 9 * 60);

      final r2 = await svc.checkOut(
        userId: budi,
        lat: latPusat,
        lng: lngPusat,
        settings: pengaturan(),
      );
      expect((r2 as Err).error.code, AppErrCode.alreadyCheckedOut);
    });

    test('checkout di luar radius → ditolak', () async {
      await buatUser(db, 'siPulangJauh');
      final siPulangJauh =
          (await db.query('users', where: "username = 'siPulangJauh'"))
              .first['id'] as String;
      maju(const Duration(minutes: 30));
      await svc.checkIn(
        userId: siPulangJauh,
        office: kantor,
        lat: latPusat,
        lng: lngPusat,
        settings: pengaturan(),
      );
      final r = await svc.checkOut(
        userId: siPulangJauh,
        lat: latJauh,
        lng: lngJauh,
        settings: pengaturan(),
      );
      expect((r as Err).error.code, AppErrCode.outsideRadius);
    });

    test('shift malam lintas tengah malam: pulang 06:00 hari berikutnya', () async {
      await buatUser(db, 'siMalam');
      final siMalam = (await db.query('users', where: "username = 'siMalam'"))
          .first['id'] as String;
      // Masuk 22:10 (hari ini 2026-10-23).
      waktu = DateTime(2026, 10, 23, 22, 10);
      await svc.checkIn(
        userId: siMalam,
        office: kantor,
        lat: latPusat,
        lng: lngPusat,
        settings: pengaturan(),
      );
      // Pulang 06:00 besok — findLatestOpen harus menemukan rekaman kemarin.
      waktu = DateTime(2026, 10, 24, 6, 0);
      final r = await svc.checkOut(
        userId: siMalam,
        lat: latPusat,
        lng: lngPusat,
        settings: pengaturan(),
      );
      expect(r, isA<Ok>());
      final rek = (r as Ok).value;
      expect(rek.day, '2026-10-23'); // kunci hari dari check-in
      expect(rek.workedMinutes, 7 * 60 + 50);
      expect(rek.statusOut, CheckOutStatus.pulangAwal);
    });

    test('verifyCheckOutGeo nonaktif → checkout tanpa koordinat bisa', () async {
      await buatUser(db, 'siLokasiLepas');
      final siLokasiLepas =
          (await db.query('users', where: "username = 'siLokasiLepas'"))
              .first['id'] as String;
      waktu = DateTime(2026, 10, 24, 8, 0);
      await svc.checkIn(
        userId: siLokasiLepas,
        office: kantor,
        lat: latPusat,
        lng: lngPusat,
        settings: pengaturan(),
      );
      waktu = DateTime(2026, 10, 24, 17, 0);
      final r = await svc.checkOut(
        userId: siLokasiLepas,
        lat: null,
        lng: null,
        settings: const AppSettings(qrSecretHex: rahasia, verifyCheckOutGeo: false),
      );
      expect(r, isA<Ok>());
      expect((r as Ok).value.checkOutLat, isNull);
    });

    test('checkout wajib geo tanpa koordinat → gpsUnavailable', () async {
      await buatUser(db, 'siTanpaGps');
      final siTanpaGps =
          (await db.query('users', where: "username = 'siTanpaGps'"))
              .first['id'] as String;
      waktu = DateTime(2026, 10, 24, 8, 5);
      await svc.checkIn(
        userId: siTanpaGps,
        office: kantor,
        lat: latPusat,
        lng: lngPusat,
        settings: pengaturan(),
      );
      waktu = DateTime(2026, 10, 24, 17, 5);
      final r = await svc.checkOut(
        userId: siTanpaGps,
        lat: null,
        lng: null,
        settings: pengaturan(),
      );
      expect((r as Err).error.code, AppErrCode.gpsUnavailable);
    });
  });

  group('manualMark', () {
    test('mencatat baru dengan jam kustom', () async {
      await buatUser(db, 'siManual');
      final siManual = (await db.query('users', where: "username = 'siManual'"))
          .first['id'] as String;
      final r = await svc.manualMark(
        userId: siManual,
        officeId: kantor.id,
        checkIn: DateTime(2026, 10, 22, 8, 0),
        checkOut: DateTime(2026, 10, 22, 18, 0),
        note: 'koreksi admin',
        settings: pengaturan(),
      );
      expect(r, isA<Ok>());
      final rek = (r as Ok).value;
      expect(rek.isManual, isTrue);
      expect(rek.status, 'lembur'); // 10 jam kerja
      expect(rek.note, 'koreksi admin');
    });

    test('upsert: rekaman terbuka dilengkapi pulang', () async {
      // siManual hari 2026-10-22 sudah lengkap; buat terbuka baru.
      final r0 = await svc.manualMark(
        userId: (await db.query('users', where: "username = 'siManual'"))
            .first['id'] as String,
        officeId: kantor.id,
        checkIn: DateTime(2026, 10, 23, 8, 0),
        settings: pengaturan(),
      );
      final id = (r0 as Ok).value.id;
      final r1 = await svc.manualMark(
        userId: (await db.query('users', where: "username = 'siManual'"))
            .first['id'] as String,
        officeId: kantor.id,
        checkIn: DateTime(2026, 10, 23, 8, 0),
        checkOut: DateTime(2026, 10, 23, 17, 0),
        settings: pengaturan(),
      );
      final rek1 = (r1 as Ok<Attendance>).value;
      expect(rek1.id, id); // rekaman sama, tidak dobel
      expect(rek1.checkOutAtMs, isNotNull);

      // Jumlah rekaman siManual tepat 2 (22 & 23).
      final jumlah = await db.rawQuery(
        'SELECT COUNT(*) c FROM attendance WHERE user_id = ?',
        [(await db.query('users', where: "username = 'siManual'")).first['id']],
      );
      expect(jumlah.first['c'], 2);
    });

    test('user/kantor tidak dikenal → notFound', () async {
      final r = await svc.manualMark(
        userId: 'ngasal',
        officeId: kantor.id,
        checkIn: DateTime(2026, 10, 23, 8, 0),
        settings: pengaturan(),
      );
      expect((r as Err).error.code, AppErrCode.notFound);
      final r2 = await svc.manualMark(
        userId: budi,
        officeId: 'ngasal',
        checkIn: DateTime(2026, 10, 23, 8, 0),
        settings: pengaturan(),
      );
      expect((r2 as Err).error.code, AppErrCode.notFound);
    });
  });

  test('rahasia QR tersimpan di settings & unik per basis data', () async {
    final s = await SettingDao(db).loadAppSettings();
    expect(s.qrSecretHex.length, 64);
    expect(s.qrSecretHex, isNot(equals(rahasia))); // seed punya rahasia sendiri
  });
}
