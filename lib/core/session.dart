/// Token sesi login: dibuat saat login, dipulihkan saat aplikasi dibuka.
library;

import 'package:hadir/core/crypto.dart';

/// Durasi sesi biasa (12 jam).
const Duration kSessionTtl = Duration(hours: 12);

/// Durasi sesi "ingat saya" (30 hari).
const Duration kSessionRememberTtl = Duration(days: 30);

class SessionToken {
  final String userId;

  /// Token acak 64 karakter hex (32 byte).
  final String tokenHex;

  final int issuedAtMs;
  final int expiresAtMs;

  const SessionToken({
    required this.userId,
    required this.tokenHex,
    required this.issuedAtMs,
    required this.expiresAtMs,
  });

  factory SessionToken.issue(
    String userId,
    Duration ttl, {
    DateTime? at,
    String? tokenHex,
  }) {
    final now = at ?? DateTime.now();
    return SessionToken(
      userId: userId,
      tokenHex: tokenHex ?? randomHex(32),
      issuedAtMs: now.millisecondsSinceEpoch,
      expiresAtMs: now.millisecondsSinceEpoch + ttl.inMilliseconds,
    );
  }

  /// Valid pada waktu [now]: >= diterbitkan dan < kedaluwarsa.
  bool isValidAt(DateTime now) {
    final issued = DateTime.fromMillisecondsSinceEpoch(issuedAtMs);
    final expires = DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
    return !now.isBefore(issued) && now.isBefore(expires);
  }

  /// Sisa masa berlaku (bisa negatif = sudah lewat).
  Duration remainingAt(DateTime now) =>
      DateTime.fromMillisecondsSinceEpoch(expiresAtMs).difference(now);

  String encode() => '$userId|$tokenHex|$issuedAtMs|$expiresAtMs';

  static SessionToken? decode(String raw) {
    final parts = raw.split('|');
    if (parts.length != 4) return null;
    final issued = int.tryParse(parts[2]);
    final expires = int.tryParse(parts[3]);
    if (issued == null || expires == null || expires <= issued) return null;
    final token = parts[1];
    final tokenBytes = tryFromHex(token);
    if (tokenBytes == null || tokenBytes.length < 16) return null;
    if (parts[0].isEmpty) return null;
    return SessionToken(
      userId: parts[0],
      tokenHex: token,
      issuedAtMs: issued,
      expiresAtMs: expires,
    );
  }
}
