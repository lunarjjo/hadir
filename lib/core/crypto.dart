/// Kriptografi inti: PBKDF2-HMAC-SHA256, HMAC-SHA256, hex, dan
/// perbandingan konstan-waktu — semuanya Dart murni agar mudah diuji.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Iterasi bawaan PBKDF2 (cukup untuk model ancaman aplikasi lokal,
/// masih cepat di perangkat Android lama).
const int kDefaultIterations = 12000;

const int _digestSize = 32;

// ---------------------------------------------------------------- hex utils

/// Ubah byte menjadi string heksadesimal huruf kecil.
String toHex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

const _hexDigits = '0123456789abcdef';

/// Parse string heksadesimal; null jika panjang ganjil atau ada karakter
/// yang bukan hex.
Uint8List? tryFromHex(String hex) {
  if (hex.length.isOdd) return null;
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    final hi = _hexDigits.indexOf(hex[i]);
    final lo = _hexDigits.indexOf(hex[i + 1]);
    if (hi < 0 || lo < 0) return null;
    out[i ~/ 2] = (hi << 4) | lo;
  }
  return out;
}

Uint8List _fromHex(String hex) => tryFromHex(hex)!;

// ---------------------------------------------------------------- hmac

/// HMAC-SHA256 dengan kunci dan data byte.
Uint8List hmacSha256(List<int> key, List<int> data) =>
    Uint8List.fromList(Hmac(sha256, key).convert(data).bytes);

/// HMAC-SHA256: kunci dari string hex (mis. rahasia QR), pesan string.
String hmacSha256Hex(String secretHex, String message) =>
    toHex(hmacSha256(_fromHex(secretHex), utf8.encode(message)));

// ---------------------------------------------------------------- pbkdf2

/// PBKDF2-HMAC-SHA256 standar (RFC 2898 dgn SHA-256).
Uint8List pbkdf2HmacSha256({
  required List<int> password,
  required List<int> salt,
  int iterations = kDefaultIterations,
  int keyLength = 32,
}) {
  if (iterations < 1) {
    throw ArgumentError.value(iterations, 'iterations', 'harus >= 1');
  }
  if (keyLength < 1) {
    throw ArgumentError.value(keyLength, 'keyLength', 'harus >= 1');
  }
  final blocks = (keyLength + _digestSize - 1) ~/ _digestSize;
  final out = BytesBuilder(copy: false);
  for (var b = 1; b <= blocks; b++) {
    final saltAndIndex = BytesBuilder(copy: false)
      ..add(salt)
      ..add([(b >> 24) & 0xff, (b >> 16) & 0xff, (b >> 8) & 0xff, b & 0xff]);
    var u = hmacSha256(password, saltAndIndex.toBytes());
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmacSha256(password, u);
      for (var j = 0; j < _digestSize; j++) {
        t[j] ^= u[j];
      }
    }
    final take =
        (b == blocks && keyLength % _digestSize != 0)
            ? keyLength % _digestSize
            : _digestSize;
    out.add(t.sublist(0, take));
  }
  return Uint8List.fromList(out.toBytes());
}

// ---------------------------------------------------------------- random

final Random _secure = Random.secure();

/// String heksadesimal acak dari [nBytes] byte kripto-aman.
String randomHex(int nBytes) {
  final bytes = Uint8List(nBytes);
  for (var i = 0; i < nBytes; i++) {
    bytes[i] = _secure.nextInt(256);
  }
  return toHex(bytes);
}

/// Bandingkan dua byte-array tanpa bocor waktu (XOR terakumulasi).
bool timingSafeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

// ---------------------------------------------------------------- password

/// Representasi hash sandi siap-simpan.
class PasswordHash {
  final int iterations;
  final String saltHex;
  final String hashHex;

  const PasswordHash({
    required this.iterations,
    required this.saltHex,
    required this.hashHex,
  });

  String encode() => 'pbkdf2-sha256\$$iterations\$$saltHex\$$hashHex';

  static PasswordHash? decode(String raw) {
    final parts = raw.split(r'$');
    if (parts.length != 4 || parts[0] != 'pbkdf2-sha256') return null;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return null;
    final salt = tryFromHex(parts[2]);
    final hash = tryFromHex(parts[3]);
    if (salt == null || hash == null) return null;
    if (salt.length < 8 || hash.isEmpty) return null;
    return PasswordHash(
      iterations: iterations,
      saltHex: parts[2],
      hashHex: parts[3],
    );
  }
}

/// Hash sandi baru dengan salt acak.
PasswordHash hashPassword(String password, {int iterations = kDefaultIterations}) {
  final saltHex = randomHex(16);
  final hashHex = toHex(pbkdf2HmacSha256(
    password: utf8.encode(password),
    salt: _fromHex(saltHex),
    iterations: iterations,
    keyLength: 32,
  ));
  return PasswordHash(iterations: iterations, saltHex: saltHex, hashHex: hashHex);
}

/// Verifikasi sandi terhadap string hash tersimpan.
bool verifyPassword(String password, String encoded) {
  final stored = PasswordHash.decode(encoded);
  if (stored == null) return false;
  final computed = toHex(pbkdf2HmacSha256(
    password: utf8.encode(password),
    salt: _fromHex(stored.saltHex),
    iterations: stored.iterations,
    keyLength: (stored.hashHex.length ~/ 2),
  ));
  return timingSafeEquals(utf8.encode(computed), utf8.encode(stored.hashHex));
}
