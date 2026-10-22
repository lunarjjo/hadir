/// Profil: identitas, ganti nama/sandi, tema tampilan, QR pribadi, keluar.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hadir/core/result.dart';
import 'package:hadir/core/validation.dart';
import 'package:hadir/state/app_bootstrap.dart';
import 'package:hadir/state/auth_provider.dart';
import 'package:hadir/state/settings_provider.dart';
import 'package:hadir/ui/login_screen.dart';
import 'package:hadir/ui/member/my_qr_screen.dart';
import 'package:hadir/ui/widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _sibuk = false;

  Future<void> _gantiNama() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    final ctl = TextEditingController(text: user.displayName);
    final hasil = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti nama tampilan'),
        content: TextFormField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama tampilan'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (hasil == null || !mounted) return;
    if (validateDisplayName(hasil) != null) {
      showAppSnack(context, 'Nama tampilan 2–48 karakter.', isError: true);
      return;
    }
    final bootstrap = context.read<AppBootstrap>();
    final r = await bootstrap.auth.changeDisplayName(user.id, hasil);
    if (!mounted) return;
    switch (r) {
      case Ok(:final value):
        auth.refreshUser(value);
        showAppSnack(context, 'Nama tampilan diperbarui.');
      case Err(:final error):
        showAppSnack(context, error.message, isError: true);
    }
  }

  Future<void> _gantiSandi() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null || _sibuk) return;
    final lama = TextEditingController();
    final baru = TextEditingController();
    final ulang = TextEditingController();
    final kunci = GlobalKey<FormState>();
    final hasil = await showDialog<bool>(
      context: context,
      builder: (ctx) => Form(
        key: kunci,
        child: AlertDialog(
          title: const Text('Ganti kata sandi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: lama,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Sandi lama'),
                validator: (v) => (v?.isEmpty ?? true) ? 'Wajib diisi.' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: baru,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Sandi baru'),
                validator: validatePassword,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: ulang,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Ulangi sandi baru',
                ),
                validator: (v) =>
                    v != baru.text ? 'Tidak sama dengan sandi baru.' : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (kunci.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (hasil != true || !mounted) return;
    setState(() => _sibuk = true);
    final bootstrap = context.read<AppBootstrap>();
    final r = await bootstrap.auth.changePassword(
      user.id,
      lama.text,
      baru.text,
    );
    if (!mounted) return;
    setState(() => _sibuk = false);
    switch (r) {
      case Ok():
        showAppSnack(context, 'Kata sandi berhasil diganti.');
      case Err(:final error):
        showAppSnack(context, error.message, isError: true);
    }
  }

  Future<void> _keluar() async {
    final auth = context.read<AuthProvider>();
    final ya = await confirmDialog(
      context,
      title: 'Keluar aplikasi?',
      message: 'Kamu perlu login lagi untuk absen selanjutnya.',
      confirmLabel: 'Keluar',
      danger: true,
    );
    if (!ya || !mounted) return;
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final user = auth.user;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Profil',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      avatarInitials(user?.displayName ?? '?'),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user?.displayName ?? '-',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '@${user?.username ?? '-'}',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  RoleChip(isAdmin: user?.isAdmin ?? false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Ganti nama tampilan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _gantiNama,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Ganti kata sandi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _gantiSandi,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Tampilan',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: settings.themeMode,
                  onChanged: (v) =>
                      v != null ? settings.setThemeMode(v) : null,
                  title: const Text('Ikuti perangkat'),
                  subtitle: const Text('Terang/gelap otomatis'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: settings.themeMode,
                  onChanged: (v) =>
                      v != null ? settings.setThemeMode(v) : null,
                  title: const Text('Terang'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: settings.themeMode,
                  onChanged: (v) =>
                      v != null ? settings.setThemeMode(v) : null,
                  title: const Text('Gelap'),
                ),
              ],
            ),
          ),
          if (user != null && !user.isAdmin) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyQrScreen()),
              ),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('QR Saya (untuk absen manual)'),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tentang aplikasi',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hadir v1.0.0 — aplikasi absensi native Flutter. '
                    'Data tersimpan lokal di perangkat (SQLite). '
                    'Lisensi MIT © 2026 lunarjjo.',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _keluar,
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
