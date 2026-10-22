/// Test aturan absensi: status masuk/pulang, lembur, lintas hari, kunci hari.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hadir/core/attendance_rules.dart';

void main() {
  const kebijakan = WorkPolicy(
    workStartMinutes: 480, // 08:00
    workEndMinutes: 1020, // 17:00
    lateGraceMinutes: 15,
    earlyLeaveGraceMinutes: 15,
    overtimeExtraMinutes: 30,
  );

  DateTime dt(int jam, int menit, [int detik = 0]) =>
      DateTime(2026, 10, 23, jam, menit, detik);

  group('evaluateCheckIn', () {
    test('tepat: sebelum jam mulai', () {
      expect(evaluateCheckIn(dt(7, 0), kebijakan), CheckInStatus.tepat);
    });

    test('tepat: tepat di batas tenggang 08:15:00', () {
      expect(evaluateCheckIn(dt(8, 15, 0), kebijakan), CheckInStatus.tepat);
    });

    test('terlambat: 08:15:01 (lewat 1 detik)', () {
      expect(
          evaluateCheckIn(dt(8, 15, 1), kebijakan), CheckInStatus.terlambat);
    });

    test('terlambat: 10:00', () {
      expect(evaluateCheckIn(dt(10, 0), kebijakan), CheckInStatus.terlambat);
    });
  });

  group('evaluateCheckOut', () {
    test('tepat: tepat jam pulang 17:00', () {
      expect(
        evaluateCheckOut(dt(8, 0), dt(17, 0), kebijakan),
        CheckOutStatus.tepat,
      );
    });

    test('pulang awal: 16:44 (sebelum 16:45)', () {
      expect(
        evaluateCheckOut(dt(8, 0), dt(16, 44), kebijakan),
        CheckOutStatus.pulangAwal,
      );
    });

    test('tepat: 16:45 (tepat batas tenggang)', () {
      expect(
        evaluateCheckOut(dt(8, 0), dt(16, 45), kebijakan),
        CheckOutStatus.tepat,
      );
    });

    test('lembur: kerja 9,5 jam (570 menit >= 540+30)', () {
      expect(
        evaluateCheckOut(dt(8, 0), dt(17, 30), kebijakan),
        CheckOutStatus.lembur,
      );
    });

    test('lembur: 17:29 belum lembur (569 < 570)', () {
      expect(
        evaluateCheckOut(dt(8, 0), dt(17, 29), kebijakan),
        CheckOutStatus.tepat,
      );
    });

    test('shift malam lintas tengah malam: 22:00→06:00 (8 jam)', () {
      final masuk = DateTime(2026, 10, 23, 22, 0);
      final pulang = DateTime(2026, 10, 24, 6, 0);
      // 480 menit < 540-15 → pulang awal menurut durasi
      expect(
        evaluateCheckOut(masuk, pulang, kebijakan),
        CheckOutStatus.pulangAwal,
      );
    });

    test('shift malam 9,5 jam → lembur', () {
      final masuk = DateTime(2026, 10, 23, 22, 0);
      final pulang = DateTime(2026, 10, 24, 7, 30);
      expect(
        evaluateCheckOut(masuk, pulang, kebijakan),
        CheckOutStatus.lembur,
      );
    });

    test('pulang sebelum masuk (masukan salah) → pulangAwal, tanpa crash', () {
      expect(
        evaluateCheckOut(dt(10, 0), dt(8, 0), kebijakan),
        CheckOutStatus.pulangAwal,
      );
    });
  });

  group('overallStatus', () {
    test('prioritas terlambat > pulang awal > lembur > hadir', () {
      expect(overallStatus(CheckInStatus.terlambat, CheckOutStatus.lembur),
          'terlambat');
      expect(overallStatus(CheckInStatus.tepat, CheckOutStatus.pulangAwal),
          'pulang_awal');
      expect(overallStatus(CheckInStatus.tepat, CheckOutStatus.lembur),
          'lembur');
      expect(overallStatus(CheckInStatus.tepat, CheckOutStatus.tepat),
          'hadir');
      expect(overallStatus(CheckInStatus.tepat, null), 'hadir');
      expect(overallStatus(CheckInStatus.terlambat, null), 'terlambat');
    });
  });

  group('dayKey / parseDayKey', () {
    test('format nol-diisi', () {
      expect(dayKey(DateTime(2026, 1, 5)), '2026-01-05');
      expect(dayKey(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('parse: valid & tidak valid', () {
      final d = parseDayKey('2026-10-23');
      expect(d, DateTime(2026, 10, 23));
      expect(parseDayKey('2026-10'), isNull);
      expect(parseDayKey('abc-def-ghi'), isNull);
      expect(parseDayKey('2026-13-01'), isNull);
      expect(parseDayKey('2026-10-32'), isNull);
    });
  });

  group('WorkPolicy', () {
    test('fullDayMinutes = pulang - mulai', () {
      expect(kebijakan.fullDayMinutes, 540);
      expect(const WorkPolicy().fullDayMinutes, 540);
    });
  });
}
