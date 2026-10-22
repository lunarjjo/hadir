/// Token QR ber-HMAC untuk absensi + QR identitas anggota.
///
/// Format token kantor: `HADIR|T|<officeId>|<issuedUnix>|<windowDetik>|<sig>`
/// Format QR anggota:   `HADIR|U|<userId>|<username>|<sig>`
///
/// `sig` = 16 byte pertama HMAC-SHA256(rahasia, badan-token) dalam hex.
library;

import 'package:hadir/core/crypto.dart';

/// Alasan token QR ditolak.
enum QrTokenProblem { badFormat, badSignature, expired, notYetValid, officeMismatch }

/// Hasil verifikasi token kantor.
class QrTokenCheck {
  final bool valid;
  final QrTokenProblem? problem;

  const QrTokenCheck._(this.valid, this.problem);

  const QrTokenCheck.ok() : this._(true, null);
  const QrTokenCheck.fail(QrTokenProblem p) : this._(false, p);
}

/// Data hasil parse QR identitas anggota (sudah lolos verifikasi).
class MemberQrData {
  final String userId;
  final String username;

  const MemberQrData({required this.userId, required this.username});
}

/// Pembuat & pemeriksa payload QR.
class QrCodec {
  final String secretHex;
  final DateTime Function() clock;

  QrCodec({required this.secretHex, required this.clock});

  static const String kPrefix = 'HADIR';
  static const int kMaxWindowSeconds = 86400;
  static const int kSigHexLength = 32; // 16 byte

  int get _nowUnix => clock().millisecondsSinceEpoch ~/ 1000;

  String _sig(String body) =>
      hmacSha256Hex(secretHex, body).substring(0, kSigHexLength);

  /// Buat token absen kantor dengan jendela waktu [windowSeconds] detik.
  ///
  /// `issuedUnix` diratakan ke kelipatan [windowSeconds] agar token
  /// deterministik dalam satu jendela (semua perangkat admin menampilkan
  /// token identik).
  String officeToken({required String officeId, required int windowSeconds}) {
    if (windowSeconds < 1 || windowSeconds > kMaxWindowSeconds) {
      throw ArgumentError.value(windowSeconds, 'windowSeconds');
    }
    if (officeId.isEmpty || officeId.contains('|')) {
      throw ArgumentError('officeId tidak boleh kosong atau berisi "|"');
    }
    final now = _nowUnix;
    final issued = now - (now % windowSeconds);
    final body = '$kPrefix|T|$officeId|$issued|$windowSeconds';
    return '$body|${_sig(body)}';
  }

  /// Verifikasi token kantor. [expectedOfficeId] opsional untuk memastikan
  /// token memang untuk kantor yang dimaksud.
  QrTokenCheck verifyOfficeToken(
    String raw, {
    String? expectedOfficeId,
    int skewSeconds = 30,
  }) {
    final parts = raw.split('|');
    if (parts.length != 6 ||
        parts[0] != kPrefix ||
        parts[1] != 'T' ||
        parts[2].isEmpty) {
      return const QrTokenCheck.fail(QrTokenProblem.badFormat);
    }
    final issued = int.tryParse(parts[3]);
    final window = int.tryParse(parts[4]);
    if (issued == null ||
        window == null ||
        window < 1 ||
        window > kMaxWindowSeconds) {
      return const QrTokenCheck.fail(QrTokenProblem.badFormat);
    }
    final sigHex = parts[5];
    final sigBytes = tryFromHex(sigHex);
    if (sigBytes == null || sigHex.length != kSigHexLength) {
      return const QrTokenCheck.fail(QrTokenProblem.badFormat);
    }
    final body = '$kPrefix|T|${parts[2]}|$issued|$window';
    final expected = tryFromHex(hmacSha256Hex(secretHex, body).substring(0, kSigHexLength));
    if (expected == null || !timingSafeEquals(sigBytes, expected)) {
      return const QrTokenCheck.fail(QrTokenProblem.badSignature);
    }
    final now = _nowUnix;
    if (now < issued - skewSeconds) {
      return const QrTokenCheck.fail(QrTokenProblem.notYetValid);
    }
    if (now > issued + window + skewSeconds) {
      return const QrTokenCheck.fail(QrTokenProblem.expired);
    }
    if (expectedOfficeId != null && parts[2] != expectedOfficeId) {
      return const QrTokenCheck.fail(QrTokenProblem.officeMismatch);
    }
    return const QrTokenCheck.ok();
  }

  /// Payload QR identitas anggota (tanpa kedaluwarsa — kartu identitas).
  String memberPayload({required String userId, required String username}) {
    if (userId.isEmpty ||
        userId.contains('|') ||
        username.contains('|')) {
      throw ArgumentError('userId/username tidak boleh kosong atau berisi "|"');
    }
    final body = '$kPrefix|U|$userId|$username';
    return '$body|${_sig(body)}';
  }

  /// Parse + verifikasi QR identitas anggota; null bila tidak valid.
  MemberQrData? parseMemberPayload(String raw) {
    final parts = raw.split('|');
    if (parts.length != 5 ||
        parts[0] != kPrefix ||
        parts[1] != 'U' ||
        parts[2].isEmpty ||
        parts[3].isEmpty) {
      return null;
    }
    final sigHex = parts[4];
    final sigBytes = tryFromHex(sigHex);
    if (sigBytes == null || sigHex.length != kSigHexLength) return null;
    final body = '$kPrefix|U|${parts[2]}|${parts[3]}';
    final expected =
        tryFromHex(hmacSha256Hex(secretHex, body).substring(0, kSigHexLength));
    if (expected == null || !timingSafeEquals(sigBytes, expected)) return null;
    return MemberQrData(userId: parts[2], username: parts[3]);
  }
}

/// Deteksi cepat: string hasil pindai adalah QR anggota?
bool isMemberPayload(String raw) {
  final parts = raw.split('|');
  return parts.length == 5 && parts[0] == QrCodec.kPrefix && parts[1] == 'U';
}

/// Deteksi cepat: string hasil pindai adalah token kantor?
bool isOfficeToken(String raw) {
  final parts = raw.split('|');
  return parts.length == 6 && parts[0] == QrCodec.kPrefix && parts[1] == 'T';
}
