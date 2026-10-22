/// Test kriptografi inti: HMAC, PBKDF2 (vektor acuan publik), hex, sandi.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:hadir/core/crypto.dart';

void main() {
  group('hex', () {
    test('toHex menghasilkan huruf kecil dua digit', () {
      expect(toHex([0, 1, 15, 16, 255]), '00010f10ff');
    });

    test('tryFromHex: valid, ganjil, karakter asing', () {
      expect(tryFromHex('0f10ff'), [15, 16, 255]);
      expect(tryFromHex('0f1'), isNull);
      expect(tryFromHex('zz'), isNull);
      expect(tryFromHex(''), []);
    });

    test('randomHex panjang & unik', () {
      final a = randomHex(16);
      final b = randomHex(16);
      expect(a.length, 32);
      expect(b.length, 32);
      expect(a, isNot(equals(b)));
    });
  });

  group('hmacSha256', () {
    test('vektor acuan: kunci "key", pesan rubah', () {
      final sig = toHex(
        hmacSha256(utf8.encode('key'),
            utf8.encode('The quick brown fox jumps over the lazy dog')),
      );
      expect(
        sig,
        'f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8',
      );
    });

    test('hmacSha256Hex konsisten dengan hmacSha256 (kunci didekode dari hex)', () {
      const secret = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const pesan = 'HADIR|T|abc|0|60';
      expect(
        hmacSha256Hex(secret, pesan),
        toHex(hmacSha256(tryFromHex(secret)!, utf8.encode(pesan))),
      );
    });
  });

  group('pbkdf2HmacSha256 (vektor acuan PBKDF2-HMAC-SHA256)', () {
    test('c=1 dkLen=32', () {
      final k = toHex(pbkdf2HmacSha256(
        password: utf8.encode('password'),
        salt: utf8.encode('salt'),
        iterations: 1,
        keyLength: 32,
      ));
      expect(
        k,
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('c=2 dkLen=32', () {
      final k = toHex(pbkdf2HmacSha256(
        password: utf8.encode('password'),
        salt: utf8.encode('salt'),
        iterations: 2,
        keyLength: 32,
      ));
      expect(
        k,
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('c=4096 dkLen=32', () {
      final k = toHex(pbkdf2HmacSha256(
        password: utf8.encode('password'),
        salt: utf8.encode('salt'),
        iterations: 4096,
        keyLength: 32,
      ));
      expect(
        k,
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });

    test('dkLen melewati blok: awal sama dengan blok pertama', () {
      final satuBlok = pbkdf2HmacSha256(
        password: utf8.encode('password'),
        salt: utf8.encode('salt'),
        iterations: 3,
        keyLength: 32,
      );
      final duaBlok = pbkdf2HmacSha256(
        password: utf8.encode('password'),
        salt: utf8.encode('salt'),
        iterations: 3,
        keyLength: 33,
      );
      expect(duaBlok.length, 33);
      expect(duaBlok.sublist(0, 32), satuBlok);
    });

    test('iterasi & panjang tidak valid melempar ArgumentError', () {
      expect(
        () => pbkdf2HmacSha256(
          password: [1], salt: [1], iterations: 0, keyLength: 32),
        throwsArgumentError,
      );
      expect(
        () => pbkdf2HmacSha256(
          password: [1], salt: [1], iterations: 1, keyLength: 0),
        throwsArgumentError,
      );
    });
  });

  group('timingSafeEquals', () {
    test('sama, beda panjang, beda isi', () {
      expect(timingSafeEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(timingSafeEquals([1, 2], [1, 2, 3]), isFalse);
      expect(timingSafeEquals([1, 2, 4], [1, 2, 3]), isFalse);
      expect(timingSafeEquals([], []), isTrue);
    });
  });

  group('PasswordHash', () {
    test('encode → decode → verifikasi sandi benar/salah', () {
      final h = hashPassword('rahasia123');
      final encoded = h.encode();
      expect(encoded.startsWith('pbkdf2-sha256\$'), isTrue);
      final decoded = PasswordHash.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.iterations, h.iterations);
      expect(decoded.saltHex, h.saltHex);
      expect(verifyPassword('rahasia123', encoded), isTrue);
      expect(verifyPassword('salah', encoded), isFalse);
    });

    test('decode menolak format rusak', () {
      expect(PasswordHash.decode(''), isNull);
      expect(PasswordHash.decode('pbkdf2-sha256'), isNull);
      expect(PasswordHash.decode('pbkdf2-sha256\$0\$aa\$bb'), isNull);
      expect(PasswordHash.decode('pbkdf2-sha256\$10\$zz\$bb'), isNull);
      expect(PasswordHash.decode('md5\$10\$aa\$bb'), isNull);
    });

    test('salt unik per panggilan', () {
      expect(hashPassword('sama').saltHex, isNot(equals(hashPassword('sama').saltHex)));
    });

    test('iterasi kustom terhormati', () {
      final h = hashPassword('x', iterations: 500);
      expect(h.iterations, 500);
      expect(verifyPassword('x', h.encode()), isTrue);
    });
  });
}
