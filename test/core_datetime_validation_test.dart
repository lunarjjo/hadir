/// Test format tanggal/jam/durasi Indonesia + validasi isian.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hadir/core/datetime_format.dart';
import 'package:hadir/core/validation.dart';

void main() {
  group('format tanggal Indonesia', () {
    // 17 Oktober 2024 jatuh hari Kamis.
    final kamis = DateTime(2024, 10, 17, 8, 4, 7);

    test('formatTanggal lengkap', () {
      expect(formatTanggal(kamis), 'Kamis, 17 Oktober 2024');
    });

    test('formatTanggalSingkat & formatBulanTahun', () {
      expect(formatTanggalSingkat(kamis), '17 Okt 2024');
      expect(formatBulanTahun(kamis), 'Oktober 2024');
    });

    test('formatJam & formatJamDetik nol-diisi', () {
      expect(formatJam(kamis), '08:04');
      expect(formatJamDetik(kamis), '08:04:07');
      expect(formatJam(DateTime(2024, 1, 1, 23, 59)), '23:59');
    });

    test('formatTanggalJam', () {
      expect(formatTanggalJam(kamis), '17 Okt 2024 08:04');
    });

    test('semua nama hari benar (Senin..Minggu)', () {
      final senin = DateTime(2024, 10, 14); // Senin
      expect(kHari[senin.weekday - 1], 'Senin');
      expect(formatTanggal(senin), 'Senin, 14 Oktober 2024');
      expect(kHari.length, 7);
      expect(kBulan.length, 12);
      expect(kBulanSingkat.length, 12);
    });
  });

  group('formatDurasi', () {
    test('menit, jam, hari', () {
      expect(formatDurasi(null), '—');
      expect(formatDurasi(-5), '—');
      expect(formatDurasi(0), '0 m');
      expect(formatDurasi(45), '45 m');
      expect(formatDurasi(60), '1 j');
      expect(formatDurasi(492), '8 j 12 m');
      expect(formatDurasi(1441), '1 h 0 j 1 m');
    });
  });

  group('formatRelatif', () {
    final kini = DateTime(2026, 10, 23, 12, 0, 0);

    test('baru saja / menit / jam / lama', () {
      expect(formatRelatif(kini, kini), 'baru saja');
      expect(formatRelatif(kini.subtract(const Duration(seconds: 30)), kini),
          'baru saja');
      expect(formatRelatif(kini.subtract(const Duration(minutes: 5)), kini),
          '5 menit lalu');
      expect(formatRelatif(kini.subtract(const Duration(hours: 2)), kini),
          '2 jam lalu');
      expect(
        formatRelatif(kini.subtract(const Duration(days: 3)), kini),
        contains('Okt'),
      );
    });

    test('masa depan → tampil sebagai stempel waktu', () {
      expect(formatRelatif(kini.add(const Duration(minutes: 5)), kini),
          contains('12:05'));
    });
  });

  group('validasi', () {
    test('username', () {
      expect(validateUsername('budi'), isNull);
      expect(validateUsername('budi.santoso_01-x'), isNull);
      expect(validateUsername(''), isNotNull);
      expect(validateUsername('ab'), isNotNull); // terlalu pendek
      expect(validateUsername('Budi'), isNotNull); // huruf besar
      expect(validateUsername('budi sandi'), isNotNull); // spasi
      expect(validateUsername('a' * 25), isNotNull); // terlalu panjang
    });

    test('normalizeUsername', () {
      expect(normalizeUsername('  Budi '), 'budi');
    });

    test('password', () {
      expect(validatePassword('abcdef'), isNull);
      expect(validatePassword('abcde'), isNotNull);
      expect(validatePassword(''), isNotNull);
      expect(validatePassword('x' * 73), isNotNull);
      expect(validatePassword('x' * 72), isNull);
    });

    test('displayName', () {
      expect(validateDisplayName('Budi'), isNull);
      expect(validateDisplayName('B'), isNotNull);
      expect(validateDisplayName(''), isNotNull);
      expect(validateDisplayName(' ' * 3), isNotNull); // kosong setelah trim
      expect(validateDisplayName('n' * 49), isNotNull);
    });

    test('koordinat & radius', () {
      expect(validateLatitude('-6.175392'), isNull);
      expect(validateLatitude('91'), isNotNull);
      expect(validateLatitude('abc'), isNotNull);
      expect(validateLatitude(''), isNotNull);
      expect(validateLongitude('106.827153'), isNull);
      expect(validateLongitude('-181'), isNotNull);
      expect(validateRadiusMeters('150'), isNull);
      expect(validateRadiusMeters('9'), isNotNull);
      expect(validateRadiusMeters('5001'), isNotNull);
      expect(validateRadiusMeters('50.5'), isNotNull);
      expect(validateOfficeName('Kantor Pusat'), isNull);
      expect(validateOfficeName('K'), isNotNull);
    });

    test('tryParseDouble menerima koma & titik desimal', () {
      expect(tryParseDouble('1.5'), 1.5);
      expect(tryParseDouble('1,5'), 1.5);
      expect(tryParseDouble('x'), isNull);
    });
  });
}
