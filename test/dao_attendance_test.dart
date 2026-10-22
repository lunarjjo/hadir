/// Test DAO absensi: kueri, filter, agregasi statistik.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:hadir/core/attendance_rules.dart';
import 'package:hadir/core/id_gen.dart';
import 'package:hadir/data/dao/attendance_dao.dart';
import 'package:hadir/data/models/attendance.dart';

import 'helpers.dart';

Attendance rekaman({
  required String userId,
  required String officeId,
  required String day,
  required int jamMasuk,
  int? jamPulang,
  String status = 'hadir',
  String statusIn = 'tepat',
  String? statusOut,
}) {
  final y = int.parse(day.substring(0, 4));
  final m = int.parse(day.substring(5, 7));
  final d = int.parse(day.substring(8, 10));
  final masuk = DateTime(y, m, d, jamMasuk).millisecondsSinceEpoch;
  final pulang = jamPulang == null
      ? null
      : DateTime(y, m, d, jamPulang).millisecondsSinceEpoch;
  return Attendance(
    id: newId(),
    userId: userId,
    officeId: officeId,
    day: day,
    checkInAtMs: masuk,
    checkInLat: -6.175392,
    checkInLng: 106.827153,
    checkInDistance: 12.5,
    checkInGeoOk: true,
    tokenOk: true,
    checkOutAtMs: pulang,
    checkOutLat: pulang == null ? null : -6.175392,
    checkOutLng: pulang == null ? null : 106.827153,
    checkOutDistance: pulang == null ? null : 15.0,
    checkOutGeoOk: pulang == null ? null : true,
    statusIn: statusIn == 'terlambat'
        ? CheckInStatus.terlambat
        : CheckInStatus.tepat,
    statusOut: statusOut == null
        ? null
        : (statusOut == 'tepat'
            ? CheckOutStatus.tepat
            : (statusOut == 'lembur'
                ? CheckOutStatus.lembur
                : CheckOutStatus.pulangAwal)),
    status: status,
    method: 'qr',
    note: null,
    createdAtMs: masuk,
    updatedAtMs: masuk,
  );
}

void main() {
  late Database db;
  late AttendanceDao dao;
  late String budi;
  late String sari;
  late String kantorA;
  late String kantorB;

  setUpAll(() async {
    db = await openTestDb();
    dao = AttendanceDao(db);
    budi = (await buatUser(db, 'budi')).id;
    sari = (await buatUser(db, 'sari')).id;
    kantorA = (await buatOffice(db, 'Kantor A')).id;
    kantorB = (await buatOffice(db, 'Kantor B')).id;
  });

  tearDownAll(() => db.close());

  test('insert → findByUserAndDay / findLatestOpen', () async {
    final r = rekaman(userId: budi, officeId: kantorA, day: '2026-10-20', jamMasuk: 8);
    await dao.insert(r);
    expect((await dao.findByUserAndDay(budi, '2026-10-20'))?.id, r.id);
    expect(await dao.findByUserAndDay(budi, '2026-10-21'), isNull);

    final terbuka =
        await dao.findLatestOpen(budi, now: DateTime(2026, 10, 20, 12));
    expect(terbuka?.id, r.id);

    // Riwayat & filter rentang.
    await dao.insert(
        rekaman(userId: budi, officeId: kantorA, day: '2026-10-21', jamMasuk: 9));
    final riwayat = await dao.historyByUser(
      budi,
      fromMs: DateTime(2026, 10, 20).millisecondsSinceEpoch,
      toMs: DateTime(2026, 10, 22).millisecondsSinceEpoch,
    );
    expect(riwayat.length, 2);
    expect(riwayat.first.checkInAtMs, greaterThan(riwayat.last.checkInAtMs));
  });

  test('findLatestOpen mengabaikan rekaman > 20 jam', () async {
    final tua = rekaman(
      userId: sari,
      officeId: kantorA,
      day: '2026-10-01',
      jamMasuk: 8,
    );
    await dao.insert(tua);
    // Rekaman lama di luar jendela 20 jam dari jam tersuntik.
    expect(
      await dao.findLatestOpen(sari, now: DateTime(2026, 10, 20, 12)),
      isNull,
    );
  });

  test('queryRecords dengan filter kombinasi', () async {
    await dao.insert(rekaman(
      userId: budi, officeId: kantorA, day: '2026-10-22', jamMasuk: 8,
      jamPulang: 17, status: 'hadir', statusOut: 'tepat'));
    await dao.insert(rekaman(
      userId: sari, officeId: kantorB, day: '2026-10-22', jamMasuk: 10,
      status: 'terlambat', statusIn: 'terlambat'));

    final semua = await dao.queryRecords(fromDay: '2026-10-22', toDay: '2026-10-22');
    expect(semua.length, 2);

    final hanyaSari =
        await dao.queryRecords(fromDay: '2026-10-22', toDay: '2026-10-22', userId: sari);
    expect(hanyaSari.length, 1);
    expect(hanyaSari.first.userId, sari);

    final hanyaKantorB = await dao.queryRecords(
        fromDay: '2026-10-22', toDay: '2026-10-22', officeId: kantorB);
    expect(hanyaKantorB.first.userId, sari);

    final hanyaTelat = await dao.queryRecords(
        fromDay: '2026-10-22', toDay: '2026-10-22', status: 'terlambat');
    expect(hanyaTelat.map((r) => r.userId), [sari]);

    final kosong = await dao.queryRecords(fromDay: '2026-01-01', toDay: '2026-01-02');
    expect(kosong, isEmpty);
  });

  test('statistik harian: countByStatusOnDay + distinct + pending', () async {
    final perStatus = await dao.countByStatusOnDay('2026-10-22');
    expect(perStatus['hadir'], 1);
    expect(perStatus['terlambat'], 1);

    expect(await dao.distinctUsersOnDay('2026-10-22'), 2);
    expect(await dao.distinctUsersOnDay('2026-10-19'), 0);

    // sari belum pulang, budi sudah → pending = 1.
    expect(await dao.countPendingCheckOutOnDay('2026-10-22'), 1);
  });

  test('seriesPerDay mengisi rentang', () async {
    final seri = await dao.seriesPerDay('2026-10-20', '2026-10-22');
    final peta = Map.fromEntries(seri);
    expect(peta['2026-10-20'], 1);
    expect(peta['2026-10-21'], 1);
    expect(peta['2026-10-22'], 2);
  });

  test('statusCountsForUser rentang bulanan', () async {
    final hasil = await dao.statusCountsForUser(budi, '2026-10-01', '2026-10-31');
    expect(hasil['hadir'], greaterThanOrEqualTo(1));
    expect(hasil.containsKey('terlambat'), isFalse); // budi tak pernah telat
  });

  test('updateFull & updateNote', () async {
    final r = rekaman(userId: budi, officeId: kantorA, day: '2026-10-23', jamMasuk: 8);
    await dao.insert(r);
    final ditutup = Attendance(
      id: r.id,
      userId: r.userId,
      officeId: r.officeId,
      day: r.day,
      checkInAtMs: r.checkInAtMs,
      checkInLat: r.checkInLat,
      checkInLng: r.checkInLng,
      checkInDistance: r.checkInDistance,
      checkInGeoOk: r.checkInGeoOk,
      tokenOk: r.tokenOk,
      checkOutAtMs: DateTime(2026, 10, 23, 17).millisecondsSinceEpoch,
      checkOutLat: -6.175392,
      checkOutLng: 106.827153,
      checkOutDistance: 20.0,
      checkOutGeoOk: true,
      statusIn: r.statusIn,
      statusOut: CheckOutStatus.lembur,
      status: 'lembur',
      method: 'qr',
      note: null,
      createdAtMs: r.createdAtMs,
      updatedAtMs: r.updatedAtMs + 1,
    );
    await dao.updateFull(ditutup);
    final hasil = await dao.findByUserAndDay(budi, '2026-10-23');
    expect(hasil?.checkOutAtMs, isNotNull);
    expect(hasil?.status, 'lembur');
    expect(hasil?.workedMinutes, 9 * 60);

    await dao.updateNote(r.id, 'dicatat ulang');
    expect((await dao.findByUserAndDay(budi, '2026-10-23'))?.note,
        'dicatat ulang');
  });

  test('countForUser', () async {
    final n = await dao.countForUser(budi);
    expect(n, greaterThanOrEqualTo(3));
  });

  test('model Attendance.fromMap/toMap bolak-balik penuh', () {
    final m = rekaman(
      userId: 'u', officeId: 'o', day: '2026-10-23', jamMasuk: 8,
      jamPulang: 17, statusOut: 'tepat',
    ).toMap();
    final r = Attendance.fromMap(m);
    expect(r.toMap(), m);
    expect(r.isManual, isFalse);
    expect(r.workedMinutes, 9 * 60);
  });
}
