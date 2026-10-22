/// Beranda anggota: status hari ini + alur absen masuk/pulang.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hadir/core/attendance_rules.dart';
import 'package:hadir/core/datetime_format.dart';
import 'package:hadir/core/geo.dart';
import 'package:hadir/core/qr_token.dart';
import 'package:hadir/core/result.dart';
import 'package:hadir/data/models/attendance.dart';
import 'package:hadir/data/models/office.dart';
import 'package:hadir/state/app_bootstrap.dart';
import 'package:hadir/state/member_provider.dart';
import 'package:hadir/state/settings_provider.dart';
import 'package:hadir/ui/member/history_screen.dart';
import 'package:hadir/ui/member/my_qr_screen.dart';
import 'package:hadir/ui/member/profile_screen.dart';
import 'package:hadir/ui/member/scan_screen.dart';
import 'package:hadir/ui/widgets/common.dart';

class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          _HomeTab(),
          HistoryScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  bool _busy = false;
  Map<String, Office> _offices = {};
  Map<String, int> _bulanan = {};
  String? _infoLokasi;
  bool _cekLokasiBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  Future<void> _muat() async {
    final bootstrap = context.read<AppBootstrap>();
    final member = context.read<MemberProvider>();
    await member.refreshToday();
    final offices = await bootstrap.admin.listOffices();
    if (!mounted) return;
    setState(() {
      _offices = {for (final o in offices) o.id: o};
    });
    _bulanan = await member.monthlyStats();
    if (mounted) setState(() {});
  }

  Future<void> _segarkan() => _muat();

  Office? _officeDariToken(String tokenRaw) {
    final bagian = tokenRaw.split('|');
    if (bagian.length < 3) return null;
    return _offices[bagian[2]];
  }

  Future<({double lat, double lng})?> _ambilLokasi() async {
    final bootstrap = context.read<AppBootstrap>();
    final hasil = await bootstrap.location.getCurrent();
    if (!mounted) return null;
    switch (hasil) {
      case Ok(:final value):
        return (lat: value.latitude, lng: value.longitude);
      case Err(:final error):
        if (error.code == AppErrCode.gpsPermissionPermanent) {
          final buka = await confirmDialog(
            context,
            title: 'Izin lokasi ditolak permanen',
            message:
                'Izin lokasi dibutuhkan untuk verifikasi keberadaan kamu di '
                'area kantor. Buka pengaturan untuk mengaktifkannya?',
            confirmLabel: 'Buka Pengaturan',
          );
          if (buka && mounted) {
            await bootstrap.location.openAppSettings();
          }
        } else {
          showAppSnack(context, error.message, isError: true);
        }
        return null;
    }
  }

  Future<void> _absenMasuk() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _infoLokasi = null;
    });
    try {
      final member = context.read<MemberProvider>();
      final settings = context.read<SettingsProvider>().settings;

      final pos = await _ambilLokasi();
      if (pos == null || !mounted) return;

      // Muat ulang kantor aktif.
      final bootstrap = context.read<AppBootstrap>();
      final offices = await bootstrap.admin.listOffices(activeOnly: true);
      if (!mounted) return;
      setState(() {
        _offices = {for (final o in offices) o.id: o};
      });

      Office? kantor;
      String? tokenRaw;
      if (settings.requireQr) {
        final hasilScan = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => const ScanPage(judul: 'Absen Masuk'),
          ),
        );
        if (!mounted || hasilScan == null) return;
        tokenRaw = hasilScan;
        if (!isOfficeToken(tokenRaw)) {
          showAppSnack(
            context,
            'QR yang dipindai bukan QR absen kantor.',
            isError: true,
          );
          return;
        }
        kantor = _officeDariToken(tokenRaw);
        if (kantor == null) {
          showAppSnack(
            context,
            'Kantor pada QR tidak dikenal atau tidak aktif.',
            isError: true,
          );
          return;
        }
      } else {
        // Tanpa QR: pilih kantor aktif terdekat yang radiusnya memuat posisi.
        Office? terdekat;
        var jarakTerdekat = double.infinity;
        for (final o in offices) {
          final d = distanceMeters(
            pos.lat,
            pos.lng,
            o.latitude,
            o.longitude,
          );
          if (d < jarakTerdekat) {
            jarakTerdekat = d;
            terdekat = o;
          }
        }
        kantor = terdekat;
        if (kantor == null) {
          showAppSnack(
            context,
            'Belum ada kantor aktif. Hubungi admin.',
            isError: true,
          );
          return;
        }
      }

      final hasil = await member.doCheckIn(
        office: kantor,
        lat: pos.lat,
        lng: pos.lng,
        tokenRaw: tokenRaw,
      );
      if (!mounted) return;
      switch (hasil) {
        case Ok(:final value):
          await _tampilkanSukses(value);
          await _segarkan();
        case Err(:final error):
          showAppSnack(context, error.message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _absenPulang() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final member = context.read<MemberProvider>();
      final pos = await _ambilLokasi();
      if (pos == null || !mounted) return;
      final hasil = await member.doCheckOut(lat: pos.lat, lng: pos.lng);
      if (!mounted) return;
      switch (hasil) {
        case Ok(:final value):
          await _tampilkanSukses(value);
          await _segarkan();
        case Err(:final error):
          showAppSnack(context, error.message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tampilkanSukses(Attendance rekaman) async {
    final statusLabel = switch (rekaman.status) {
      'terlambat' => 'Terlambat',
      'pulang_awal' => 'Pulang Awal',
      'lembur' => 'Lembur',
      _ => 'Hadir',
    };
    await infoDialog(
      context,
      title: 'Absen tersimpan',
      icon: rekaman.status == 'terlambat' || rekaman.status == 'pulang_awal'
          ? Icons.warning_amber_rounded
          : Icons.check_circle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status: $statusLabel'),
          const SizedBox(height: 4),
          Text('Masuk: ${formatJam(rekaman.checkInAt)}'),
          if (rekaman.checkOutAt != null) ...[
            const SizedBox(height: 4),
            Text('Pulang: ${formatJam(rekaman.checkOutAt!)}'),
          ],
          const SizedBox(height: 4),
          Text(
            'Jarak ke kantor: ${formatDistance(rekaman.checkInDistance)}',
          ),
        ],
      ),
    );
  }

  Future<void> _cekLokasi() async {
    if (_cekLokasiBusy) return;
    setState(() => _cekLokasiBusy = true);
    try {
      final pos = await _ambilLokasi();
      if (pos == null || !mounted) return;
      final bootstrap = context.read<AppBootstrap>();
      final offices = await bootstrap.admin.listOffices(activeOnly: true);
      if (!mounted) return;
      if (offices.isEmpty) {
        setState(() => _infoLokasi = 'Belum ada kantor aktif.');
        return;
      }
      Office? terdekat;
      var jarakMin = double.infinity;
      for (final o in offices) {
        final d = distanceMeters(pos.lat, pos.lng, o.latitude, o.longitude);
        if (d < jarakMin) {
          jarakMin = d;
          terdekat = o;
        }
      }
      final dalam = jarakMin <= (terdekat?.radiusMeters ?? 0);
      setState(() {
        _infoLokasi =
            'Kantor terdekat: ${terdekat!.name} (${formatDistance(jarakMin)}) '
            '— ${dalam ? 'di dalam' : 'di luar'} radius absen.';
      });
    } finally {
      if (mounted) setState(() => _cekLokasiBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = context.watch<MemberProvider>();
    final user = member.user;
    final rekaman = member.today;
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _segarkan,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hai, ${user?.displayName ?? ''}',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        formatTanggal(now),
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'QR Saya',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyQrScreen()),
                  ),
                  icon: const Icon(Icons.qr_code_2),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _kartuHariIni(context, rekaman),
            const SizedBox(height: 12),
            _kartuLokasi(context),
            const SizedBox(height: 12),
            _kartuBulanan(context),
          ],
        ),
      ),
    );
  }

  Widget _kartuHariIni(BuildContext context, Attendance? rekaman) {
    final r = rekaman;
    final sudahMasuk = r != null;
    final sudahPulang = rekaman?.checkOutAtMs != null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.today_outlined),
                const SizedBox(width: 8),
                Text(
                  'Absen hari ini',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (r != null) StatusBadge(status: r.status),
              ],
            ),
            const SizedBox(height: 12),
            if (r == null)
              Text(
                'Kamu belum absen masuk. Tekan tombol di bawah — siapkan '
                'posisi GPS aktif${context.read<SettingsProvider>().settings.requireQr ? ' dan QR dari admin' : ''}.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else ...[
              _barisWaktu(
                context,
                ikon: Icons.login,
                label: 'Masuk',
                jam: formatJam(r.checkInAt),
                tambahan:
                    '${r.statusIn == CheckInStatus.tepat ? 'tepat' : 'terlambat'} · '
                    '${formatDistance(r.checkInDistance)}',
              ),
              if (sudahPulang)
                _barisWaktu(
                  context,
                  ikon: Icons.logout,
                  label: 'Pulang',
                  jam: formatJam(r.checkOutAt!),
                  tambahan:
                      '${formatDurasi(r.workedMinutes)} kerja · '
                      '${formatDistance(r.checkOutDistance ?? 0)}',
                )
              else
                Text(
                  'Belum absen pulang.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _busy
                  ? const OutlinedButton(
                      onPressed: null,
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : sudahPulang
                      ? OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.task_alt),
                          label: const Text('Absensi hari ini lengkap'),
                        )
                      : FilledButton.icon(
                          onPressed: sudahMasuk ? _absenPulang : _absenMasuk,
                          icon: Icon(sudahMasuk ? Icons.logout : Icons.login),
                          label: Text(
                            sudahMasuk ? 'Absen Pulang' : 'Absen Masuk',
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barisWaktu(
    BuildContext context, {
    required IconData ikon,
    required String label,
    required String jam,
    required String tambahan,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(ikon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(jam, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                tambahan,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kartuLokasi(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined),
                const SizedBox(width: 8),
                Text(
                  'Lokasi sekarang',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _infoLokasi ??
                  'Periksa jarakmu ke kantor sebelum absen (hemat baterai: '
                  'GPS hanya diambil saat diperlukan).',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _cekLokasiBusy ? null : _cekLokasi,
                icon: _cekLokasiBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.radar),
                label: const Text('Cek lokasi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuBulanan(BuildContext context) {
    final hadir = _bulanan['hadir'] ?? 0;
    final terlambat = _bulanan['terlambat'] ?? 0;
    final pulangAwal = _bulanan['pulang_awal'] ?? 0;
    final lembur = _bulanan['lembur'] ?? 0;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bulan ini (${formatBulanTahun(DateTime.now())})',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const StatusBadge(status: 'hadir'),
                Text('$hadir', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                const StatusBadge(status: 'terlambat'),
                Text('$terlambat', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                const StatusBadge(status: 'pulang_awal'),
                Text('$pulangAwal', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                const StatusBadge(status: 'lembur'),
                Text('$lembur', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
