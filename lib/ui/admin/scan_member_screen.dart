/// Pindai QR identitas anggota → konfirmasi → catat absen manual.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hadir/core/qr_token.dart';
import 'package:hadir/core/result.dart';
import 'package:hadir/state/admin_provider.dart';
import 'package:hadir/ui/member/scan_screen.dart';
import 'package:hadir/ui/widgets/common.dart';

class ScanMemberScreen extends StatefulWidget {
  const ScanMemberScreen({super.key});

  @override
  State<ScanMemberScreen> createState() => _ScanMemberScreenState();
}

class _ScanMemberScreenState extends State<ScanMemberScreen> {
  bool _sibuk = false;

  Future<void> _pindai() async {
    if (_sibuk) return;
    final hasil = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage(judul: 'Pindai QR Anggota')),
    );
    if (hasil == null || !mounted) return;

    if (isOfficeToken(hasil)) {
      showAppSnack(
        context,
        'Itu QR absen kantor. Di sini yang dipindai QR identitas anggota.',
        isError: true,
      );
      return;
    }
    if (!isMemberPayload(hasil)) {
      showAppSnack(context, 'QR bukan milik aplikasi Hadir.', isError: true);
      return;
    }

    final admin = context.read<AdminProvider>();
    final data = admin.verifyMemberQr(hasil);
    if (data == null) {
      showAppSnack(
        context,
        'Tanda tangan QR tidak valid (rahasia berbeda?).',
        isError: true,
      );
      return;
    }

    await admin.refreshMembers();
    if (!mounted) return;
    final anggota = admin.members
        .where((u) => u.id == data.userId)
        .firstOrNull;
    if (anggota == null) {
      showAppSnack(
        context,
        'Anggota tidak ditemukan atau sudah dihapus.',
        isError: true,
      );
      return;
    }
    if (!anggota.active) {
      showAppSnack(
        context,
        'Akun ${anggota.displayName} sedang nonaktif.',
        isError: true,
      );
      return;
    }

    final offices = await admin.refreshOffices(activeOnly: true);
    if (!mounted) return;
    if (offices.isEmpty) {
      showAppSnack(
        context,
        'Tambahkan kantor aktif dulu sebelum absen manual.',
        isError: true,
      );
      return;
    }
    String officeId = offices.first.id;

    final catat = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Catat absen manual?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${anggota.displayName} (@${anggota.username})'),
              Text(
                'Masuk akan dicatat sekarang (${TimeOfDay.now().format(ctx)}).',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: officeId,
                decoration: const InputDecoration(labelText: 'Kantor'),
                items: [
                  for (final o in offices)
                    DropdownMenuItem(value: o.id, child: Text(o.name)),
                ],
                onChanged: (v) =>
                    v == null ? null : setDlg(() => officeId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Catat'),
            ),
          ],
        ),
      ),
    );
    if (catat != true || !mounted) return;

    setState(() => _sibuk = true);
    final r = await admin.manualMark(
      userId: anggota.id,
      officeId: officeId,
      checkIn: DateTime.now(),
      note: 'Absen manual via QR oleh admin',
    );
    if (!mounted) return;
    setState(() => _sibuk = false);
    switch (r) {
      case Ok():
        showAppSnack(context, 'Absen ${anggota.displayName} dicatat.');
      case Err(:final error):
        showAppSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pindai QR Anggota')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.crop_free,
                  size: 44,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Absen manual lewat QR',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Minta anggota membuka menu "QR Saya" di profilnya, lalu '
                'pindai QR tersebut untuk mencatat kehadiran secara manual.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _sibuk ? null : _pindai,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Buka Kamera'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
