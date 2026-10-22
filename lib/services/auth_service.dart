/// Autentikasi: login + lockout, sesi, ganti sandi/nama.
library;

import 'package:sqflite/sqflite.dart';

import 'package:hadir/core/crypto.dart';
import 'package:hadir/core/result.dart';
import 'package:hadir/core/session.dart';
import 'package:hadir/data/dao/setting_dao.dart';
import 'package:hadir/data/dao/user_dao.dart';
import 'package:hadir/data/models/user.dart';

class AuthService {
  final DateTime Function() _clock;
  final UserDao _users;
  final SettingDao _settings;

  AuthService(Database db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _users = UserDao(db),
        _settings = SettingDao(db);

  static const int kMaxFailedAttempts = 5;
  static const Duration kLockDuration = Duration(minutes: 15);

  /// Login; menyimpan sesi ke settings saat sukses.
  Future<Result<SessionToken>> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    final uname = username.trim().toLowerCase();
    final user = await _users.findByUsername(uname);
    if (user == null) {
      // Mitigasi timing: tetap kerjakan PBKDF2 walau user tak ada.
      hashPassword(password, iterations: kDefaultIterations ~/ 4);
      return err(AppErrCode.invalidCredentials);
    }
    if (!user.active) return err(AppErrCode.inactive);

    final now = _clock();
    final nowMs = now.millisecondsSinceEpoch;
    if (user.lockedUntilMs != null && nowMs < user.lockedUntilMs!) {
      final sisaMenit = ((user.lockedUntilMs! - nowMs) / 60000).ceil();
      return err(AppErrCode.locked, params: {'menit': sisaMenit});
    }

    final secret = await _users.findSecret(user.id);
    final sandiBenar = secret != null && verifyPassword(password, secret.encoded);
    if (!sandiBenar) {
      final fails = user.failedAttempts + 1;
      final harusKunci = fails >= kMaxFailedAttempts;
      await _users.updateLoginState(
        user.id,
        harusKunci ? 0 : fails,
        harusKunci ? nowMs + kLockDuration.inMilliseconds : null,
      );
      return err(AppErrCode.invalidCredentials);
    }

    await _users.updateLoginState(user.id, 0, null);
    final session = SessionToken.issue(
      user.id,
      rememberMe ? kSessionRememberTtl : kSessionTtl,
      at: now,
    );
    await _settings.set('session', session.encode());
    return ok(session);
  }

  /// Pulihkan sesi tersimpan (dipakai saat aplikasi dibuka).
  Future<Result<User>> restoreSession() async {
    final raw = await _settings.get('session');
    if (raw == null) return err(AppErrCode.generic);
    final session = SessionToken.decode(raw);
    if (session == null || !session.isValidAt(_clock())) {
      await logout();
      return err(AppErrCode.generic);
    }
    final user = await _users.findById(session.userId);
    if (user == null || !user.active) {
      await logout();
      return err(AppErrCode.generic);
    }
    return ok(user);
  }

  Future<void> logout() => _settings.delete('session');

  /// Ganti sandi: verifikasi sandi lama dulu.
  Future<Result<bool>> changePassword(
    String userId,
    String oldPassword,
    String newPassword,
  ) async {
    final secret = await _users.findSecret(userId);
    if (secret == null) return err(AppErrCode.notFound);
    if (!verifyPassword(oldPassword, secret.encoded)) {
      return err(AppErrCode.invalidCredentials);
    }
    await _users.updatePassword(userId, hashPassword(newPassword));
    return ok(true);
  }

  /// Ganti nama tampilan.
  Future<Result<User>> changeDisplayName(String userId, String newName) async {
    final user = await _users.findById(userId);
    if (user == null) return err(AppErrCode.notFound);
    final updated = user.copyWith(
      displayName: newName.trim(),
      updatedAtMs: _clock().millisecondsSinceEpoch,
    );
    await _users.updateProfile(updated);
    return ok(updated);
  }
}
