/// Pengaturan aplikasi + preferensi tema (ikut perangkat secara bawaan).
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hadir/core/qr_token.dart';
import 'package:hadir/data/dao/setting_dao.dart';
import 'package:hadir/data/models/app_settings.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingDao _dao;
  final SharedPreferences _prefs;
  AppSettings _settings;
  ThemeMode _themeMode;

  SettingsProvider(this._dao, this._settings, this._prefs)
      : _themeMode = _readTheme(_prefs.getString('theme_mode'));

  AppSettings get settings => _settings;
  ThemeMode get themeMode => _themeMode;

  static ThemeMode _readTheme(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _writeTheme(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString('theme_mode', _writeTheme(mode));
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    await _dao.saveAppSettings(newSettings);
    _settings = newSettings;
    notifyListeners();
  }

  /// Codec QR dengan jam nyata.
  QrCodec get qrCodec =>
      QrCodec(secretHex: _settings.qrSecretHex, clock: DateTime.now);
}
