/// Status autentikasi aplikasi.
library;

import 'package:flutter/foundation.dart';

import 'package:hadir/core/result.dart';
import 'package:hadir/core/session.dart';
import 'package:hadir/data/models/user.dart';
import 'package:hadir/services/auth_service.dart';

enum AuthStatus { loading, loggedOut, authenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _auth;

  AuthStatus _status = AuthStatus.loading;
  User? _user;

  /// Dipanggil setiap user aktif berubah (login/logout/restore).
  void Function(User?)? onUserChanged;

  AuthProvider(this._auth);

  AuthStatus get status => _status;
  User? get user => _user;
  bool get isAdmin => _user?.isAdmin ?? false;

  /// Pulihkan sesi tersimpan; dipanggil sekali dari splash.
  Future<void> restore() async {
    final result = await _auth.restoreSession();
    switch (result) {
      case Ok(:final value):
        _user = value;
        _status = AuthStatus.authenticated;
      case Err():
        _user = null;
        _status = AuthStatus.loggedOut;
    }
    onUserChanged?.call(_user);
    notifyListeners();
  }

  Future<Result<SessionToken>> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    final result = await _auth.login(
      username,
      password,
      rememberMe: rememberMe,
    );
    if (result is Ok) {
      // Muat user dari sesi yang barusan tersimpan.
      await restore();
    }
    return result;
  }

  Future<void> logout() async {
    await _auth.logout();
    _user = null;
    _status = AuthStatus.loggedOut;
    onUserChanged?.call(null);
    notifyListeners();
  }

  void refreshUser(User user) {
    _user = user;
    notifyListeners();
  }
}
