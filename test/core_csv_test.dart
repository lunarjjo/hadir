/// Test CSV: escape RFC 4180 + BOM.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hadir/core/csv.dart';

void main() {
  group('csvEscape', () {
    test('teks polos tanpa kutip', () {
      expect(csvEscape('biasa'), 'biasa');
    });

    test('koma, kutip, baris baru dikutip & di-escape', () {
      expect(csvEscape('a,b'), '"a,b"');
      expect(csvEscape('dia berkata "hai"'), '"dia berkata ""hai"""');
      expect(csvEscape('baris\nbaru'), '"baris\nbaru"');
      expect(csvEscape('x\ry'), '"x\ry"');
    });
  });

  group('buildCsv', () {
    test('header + baris + BOM + newline', () {
      final csv = buildCsv(['A', 'B'], [
        ['1', '2'],
      ]);
      expect(csv.startsWith(kBom), isTrue);
      expect(csv, contains('A,B'));
      expect(csv, contains('1,2'));
      expect(csv.endsWith('\n'), isTrue);
    });

    test('data dengan karakter spesial tetap satu baris logis', () {
      final csv = buildCsv(['Nama'], [
        ['Budi, "si cepat"'],
      ]);
      final baris = csv.substring(1).trim().split('\n');
      expect(baris.length, 2);
      expect(baris[1], '"Budi, ""si cepat"""');
    });

    test('kosong → hanya header', () {
      final csv = buildCsv(['A'], []);
      expect(csv, '\uFEFFA\n');
    });

    test('unicode utuh', () {
      final csv = buildCsv(['S'], [['✔']]);
      expect(csv.contains('✔'), isTrue);
    });
  });
}
