/// Test token QR ber-HMAC: verifikasi, manipulasi, jendela waktu.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hadir/core/qr_token.dart';

void main() {
  const rahasia = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const rahasiaB = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const rahasiaC = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  final dasar = DateTime(2026, 10, 23, 8, 0, 0);
  DateTime jam(int menitTambah) =>
      dasar.add(Duration(minutes: menitTambah));

  QrCodec codec({int menit = 0, String secret = rahasia}) =>
      QrCodec(secretHex: secret, clock: () => jam(menit));

  const officeId = 'office-001';

  group('token kantor', () {
    test('generate → verify valid', () {
      final token = codec().officeToken(officeId: officeId, windowSeconds: 300);
      expect(codec().verifyOfficeToken(token, expectedOfficeId: officeId).valid,
          isTrue);
    });

    test('token deterministik dalam satu jendela (rata ke kelipatan)', () {
      final a = codec().officeToken(officeId: officeId, windowSeconds: 60);
      final b = codec(menit: 1).officeToken(officeId: officeId, windowSeconds: 60);
      expect(a, isNot(equals(b))); // jendela berikutnya beda token

      // Dalam jendela yang sama (detik 0 vs 30): issued sama → token sama.
      final codecA = QrCodec(
        secretHex: 'a' * 64,
        clock: () => DateTime.fromMillisecondsSinceEpoch(
            1761187200000), // kelipatan 60
      );
      final codecB = QrCodec(
        secretHex: 'a' * 64,
        clock: () => DateTime.fromMillisecondsSinceEpoch(
            1761187200000 + 30000),
      );
      expect(
        codecA.officeToken(officeId: officeId, windowSeconds: 60),
        equals(codecB.officeToken(officeId: officeId, windowSeconds: 60)),
      );
    });

    test('kadaluwarsa: lewat jendela + skew → expired', () {
      final token = codec().officeToken(officeId: officeId, windowSeconds: 60);
      // 60 detik jendela + 30 skew → menit ke-2 masih valid? 120 > 60+30 → expired
      expect(
        codec(menit: 2).verifyOfficeToken(token).problem,
        QrTokenProblem.expired,
      );
      // 90 detik = tepat batas jendela+skew → masih valid (<=)
      expect(codec(menit: 1).verifyOfficeToken(codec().officeToken(officeId: officeId, windowSeconds: 60)).valid, isTrue);
    });

    test('belum berlaku: jam pemindai tertinggal > skew', () {
      final token = codec(menit: 5).officeToken(officeId: officeId, windowSeconds: 60);
      final hasil = codec(menit: 0).verifyOfficeToken(token);
      expect(hasil.valid, isFalse);
      expect(hasil.problem, QrTokenProblem.notYetValid);
    });

    test('segmen dimanipulasi → badSignature', () {
      final token = codec().officeToken(officeId: officeId, windowSeconds: 300);
      final bagian = token.split('|');
      bagian[2] = 'office-999'; // ganti officeId tanpa regen sig
      expect(
        codec().verifyOfficeToken(bagian.join('|')).problem,
        QrTokenProblem.badSignature,
      );
      bagian[2] = officeId;
      bagian[5] = ('0' == bagian[5][0]) ? '1${bagian[5].substring(1)}' : '0${bagian[5].substring(1)}';
      expect(
        codec().verifyOfficeToken(bagian.join('|')).problem,
        QrTokenProblem.badSignature,
      );
    });

    test('rahasia berbeda → badSignature', () {
      final token = codec().officeToken(officeId: officeId, windowSeconds: 300);
      expect(
        codec(secret: rahasiaB).verifyOfficeToken(token).problem,
        QrTokenProblem.badSignature,
      );
    });

    test('office mismatch', () {
      final token = codec().officeToken(officeId: officeId, windowSeconds: 300);
      expect(
        codec().verifyOfficeToken(token, expectedOfficeId: 'office-lain').problem,
        QrTokenProblem.officeMismatch,
      );
    });

    test('format rusak → badFormat', () {
      expect(codec().verifyOfficeToken('').problem, QrTokenProblem.badFormat);
      expect(codec().verifyOfficeToken('HADIR|T|x').problem,
          QrTokenProblem.badFormat);
      expect(codec().verifyOfficeToken('HADIR|T|a|b|c|d').problem,
          QrTokenProblem.badFormat);
      expect(codec().verifyOfficeToken('HADIR|T|a|123|abc|0123456789abcdef0123456789abcdef').problem,
          QrTokenProblem.badFormat); // window bukan angka
      expect(
        codec().verifyOfficeToken('HADIR|T|a|0|999999999|abababababababababababababababab').problem,
        QrTokenProblem.badFormat, // window > maksimum
      );
      expect(
        codec().verifyOfficeToken('HADIR|T|a|0|60|pendek').problem,
        QrTokenProblem.badFormat, // sig terlalu pendek
      );
    });

    test('argumen generate tidak valid melempar', () {
      expect(() => codec().officeToken(officeId: '', windowSeconds: 60),
          throwsArgumentError);
      expect(() => codec().officeToken(officeId: 'a|b', windowSeconds: 60),
          throwsArgumentError);
      expect(() => codec().officeToken(officeId: 'a', windowSeconds: 0),
          throwsArgumentError);
      expect(() => codec().officeToken(officeId: 'a', windowSeconds: 86401),
          throwsArgumentError);
    });
  });

  group('QR anggota', () {
    test('payload → parse valid', () {
      final p = codec().memberPayload(userId: 'user-1', username: 'budi');
      final data = codec().parseMemberPayload(p);
      expect(data, isNotNull);
      expect(data!.userId, 'user-1');
      expect(data.username, 'budi');
    });

    test('dimanipulasi → null', () {
      final p = codec().memberPayload(userId: 'user-1', username: 'budi');
      expect(codec().parseMemberPayload('$p-x'), isNull);
      final bagian = p.split('|');
      bagian[2] = 'user-2';
      expect(codec().parseMemberPayload(bagian.join('|')), isNull);
    });

    test('rahasia berbeda → null', () {
      final p = codec().memberPayload(userId: 'user-1', username: 'budi');
      expect(codec(secret: rahasiaC).parseMemberPayload(p), isNull);
    });
  });

  group('deteksi tipe payload', () {
    test('isOfficeToken / isMemberPayload', () {
      final t = codec().officeToken(officeId: 'o', windowSeconds: 60);
      final u = codec().memberPayload(userId: 'u', username: 'n');
      expect(isOfficeToken(t), isTrue);
      expect(isMemberPayload(t), isFalse);
      expect(isMemberPayload(u), isTrue);
      expect(isOfficeToken(u), isFalse);
      expect(isOfficeToken('bukan-hadir'), isFalse);
    });
  });
}
