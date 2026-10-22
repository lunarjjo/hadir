/// Splash: pulihkan sesi lalu arahkan ke login / beranda sesuai peran.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hadir/state/auth_provider.dart';
import 'package:hadir/ui/admin/admin_home_screen.dart';
import 'package:hadir/ui/login_screen.dart';
import 'package:hadir/ui/member/member_home_screen.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    await auth.restore();
    if (!mounted) return;
    final user = auth.user;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => user == null
            ? const LoginScreen()
            : (user.isAdmin
                ? const AdminHomeScreen()
                : const MemberHomeScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.onPrimary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                'H',
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Hadir',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Absensi dalam satu aplikasi',
              style: TextStyle(color: cs.onPrimary.withAlpha(200)),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: cs.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
