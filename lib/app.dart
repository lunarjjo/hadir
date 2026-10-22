/// Kerangka MaterialApp: tema ikut perangkat + penyedia state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:hadir/state/admin_provider.dart';
import 'package:hadir/state/app_bootstrap.dart';
import 'package:hadir/state/auth_provider.dart';
import 'package:hadir/state/member_provider.dart';
import 'package:hadir/state/settings_provider.dart';
import 'package:hadir/theme/app_theme.dart';
import 'package:hadir/ui/splash_screen.dart';

class HadirApp extends StatelessWidget {
  final AppBootstrap bootstrap;

  const HadirApp({super.key, required this.bootstrap});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: bootstrap.authProvider),
        ChangeNotifierProvider<SettingsProvider>.value(
          value: bootstrap.settingsProvider,
        ),
        ChangeNotifierProvider<MemberProvider>.value(
          value: bootstrap.memberProvider,
        ),
        ChangeNotifierProvider<AdminProvider>.value(
          value: bootstrap.adminProvider,
        ),
        Provider<AppBootstrap>.value(value: bootstrap),
      ],
      child: ListenableBuilder(
        listenable: bootstrap.settingsProvider,
        builder: (context, _) {
          return MaterialApp(
            title: 'Hadir',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: bootstrap.settingsProvider.themeMode,
            supportedLocales: const [Locale('id'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SplashPage(),
          );
        },
      ),
    );
  }
}
