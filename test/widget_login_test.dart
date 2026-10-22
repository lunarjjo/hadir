/// Widget test: aplikasi utuh (DB FFI NoIsolate) — login admin/salah/member.
///
/// Memakai pompa frame berbatas (tanpa pumpAndSettle) karena layar splash
/// memuat indikator memutar abadi.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hadir/app.dart';
import 'package:hadir/core/result.dart';
import 'package:hadir/state/app_bootstrap.dart';

Future<AppBootstrap> siapkanApp() async {
  sqfliteFfiInit();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final dir = await Directory.systemTemp.createTemp('hadir-widget');
  final b = await AppBootstrap.init(
    // NoIsolate: wajib untuk widget test (fake async tidak menyukai
    // isolate database FFI).
    dbFactory: databaseFactoryFfiNoIsolate,
    dbPath: '${dir.path}/widget.db',
  );
  // Tambah satu anggota untuk skenario login member.
  final r = await b.admin.addMember(
    username: 'budi',
    displayName: 'Budi Santoso',
    role: 'member',
    password: 'sandibudi',
  );
  expect(r, isA<Ok>());
  return b;
}

/// Pompa frame berbatas melewati splash + pemulihan sesi + navigasi.
Future<void> _lewatiSplash(WidgetTester tester) async {
  await tester.pump(); // bangun splash, mulai pemulihan sesi
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1)); // navigasi ke login
}

/// Pompa frame berbatas untuk alur login (PBKDF2 + DB + navigasi).
Future<void> _pompaiPascaLogin(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _login(
  WidgetTester tester,
  String username,
  String password,
) async {
  await tester.enterText(
    find.byKey(const Key('loginUsernameField')),
    username,
  );
  await tester.enterText(
    find.byKey(const Key('loginPasswordField')),
    password,
  );
  await tester.tap(find.byKey(const Key('loginSubmit')));
}

void main() {
  testWidgets('login admin → dashboard admin tampil', (tester) async {
    final b = (await tester.runAsync(siapkanApp))!;
    await tester.pumpWidget(HadirApp(bootstrap: b));
    await _lewatiSplash(tester);

    // Splash selesai → layar login.
    expect(find.byKey(const Key('loginUsernameField')), findsOneWidget);

    await _login(tester, 'admin', 'admin123');
    await _pompaiPascaLogin(tester);

    expect(find.text('Hadir · Admin'), findsOneWidget);
    expect(find.byKey(const Key('loginUsernameField')), findsNothing);
  });

  testWidgets('login salah → pesan galat, tetap di layar login', (tester) async {
    final b = (await tester.runAsync(siapkanApp))!;
    await tester.pumpWidget(HadirApp(bootstrap: b));
    await _lewatiSplash(tester);

    await _login(tester, 'admin', 'salahtotal');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Username atau kata sandi salah.'), findsOneWidget);
    expect(find.byKey(const Key('loginUsernameField')), findsOneWidget);
  });

  testWidgets('login member → beranda anggota tampil', (tester) async {
    final b = (await tester.runAsync(siapkanApp))!;
    await tester.pumpWidget(HadirApp(bootstrap: b));
    await _lewatiSplash(tester);

    await _login(tester, 'budi', 'sandibudi');
    await _pompaiPascaLogin(tester);

    expect(find.text('Hai, Budi Santoso'), findsOneWidget);
    expect(find.text('Absen hari ini'), findsOneWidget);
  });

  testWidgets('tema gelap sistem diterapkan ke login', (tester) async {
    final b = (await tester.runAsync(siapkanApp))!;
    tester.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    await tester.pumpWidget(HadirApp(bootstrap: b));
    await _lewatiSplash(tester);

    final elemen =
        tester.element(find.byKey(const Key('loginUsernameField')));
    expect(Theme.of(elemen).brightness, Brightness.dark);
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
}
