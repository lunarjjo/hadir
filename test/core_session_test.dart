/// Test token sesi: penerbitan, batas kedaluwarsa, encode/decode.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:hadir/core/session.dart';

void main() {
  final kini = DateTime(2026, 10, 23, 8, 0, 0);

  group('SessionToken', () {
    test('issue + isValidAt dalam masa', () {
      final s = SessionToken.issue('user-1', kSessionTtl, at: kini);
      expect(s.isValidAt(kini), isTrue);
      expect(s.isValidAt(kini.add(const Duration(hours: 11))), isTrue);
      expect(
        s.isValidAt(kini.add(kSessionTtl)), // tepat kedaluwarsa
        isFalse,
      );
      expect(
        s.isValidAt(kini.subtract(const Duration(seconds: 1))),
        isFalse, // sebelum diterbitkan
      );
    });

    test('TTL ingat-saya 30 hari', () {
      final s = SessionToken.issue('u', kSessionRememberTtl, at: kini);
      expect(
        s.isValidAt(kini.add(const Duration(days: 29))),
        isTrue,
      );
      expect(s.isValidAt(kini.add(kSessionRememberTtl)), isFalse);
    });

    test('encode → decode identik', () {
      final s = SessionToken.issue('user-9', kSessionTtl, at: kini);
      final d = SessionToken.decode(s.encode());
      expect(d, isNotNull);
      expect(d!.userId, 'user-9');
      expect(d.tokenHex, s.tokenHex);
      expect(d.issuedAtMs, s.issuedAtMs);
      expect(d.expiresAtMs, s.expiresAtMs);
    });

    test('decode menolak format rusak', () {
      expect(SessionToken.decode(''), isNull);
      expect(SessionToken.decode('a|b|c'), isNull);
      expect(SessionToken.decode('a|b|1|0'), isNull); // expires <= issued
      expect(SessionToken.decode('|hexhexhexhexhexhex|1|2'), isNull); // userId kosong
      expect(SessionToken.decode('a|zzz|1|2'), isNull); // token bukan hex
      expect(SessionToken.decode('a|abcd|1|2'), isNull); // terlalu pendek
    });

    test('remainingAt', () {
      final s = SessionToken.issue('u', const Duration(hours: 1), at: kini);
      expect(
        s.remainingAt(kini.add(const Duration(minutes: 30))).inMinutes,
        30,
      );
      expect(s.remainingAt(kini.add(const Duration(hours: 2))).isNegative,
          isTrue);
    });
  });
}
