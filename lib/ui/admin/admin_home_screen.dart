/// Beranda admin: shell 4 tab + dashboard statistik + grafik 7 hari.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hadir/core/datetime_format.dart';
import 'package:hadir/services/admin_service.dart';
import 'package:hadir/state/admin_provider.dart';
import 'package:hadir/state/auth_provider.dart';
import 'package:hadir/ui/admin/members_screen.dart';
import 'package:hadir/ui/admin/offices_screen.dart';
import 'package:hadir/ui/admin/qr_generator_screen.dart';
import 'package:hadir/ui/admin/records_screen.dart';
import 'package:hadir/ui/admin/scan_member_screen.dart';
import 'package:hadir/ui/member/profile_screen.dart';
import 'package:hadir/ui/widgets/bar_chart.dart';
import 'package:hadir/ui/widgets/common.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hadir · Admin'),
        actions: [
          IconButton(
            tooltip: 'QR Absen',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QrGeneratorScreen()),
            ),
            icon: const Icon(Icons.qr_code_2),
          ),
          IconButton(
            tooltip: 'Pindai QR Anggota',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanMemberScreen()),
            ),
            icon: const Icon(Icons.crop_free),
          ),
          IconButton(
            tooltip: 'Profil',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          _DashboardTab(),
          MembersScreen(),
          OfficesScreen(),
          RecordsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Anggota',
          ),
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: 'Kantor',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Rekap',
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  Future<AdminDashboard>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  Future<void> _muat() {
    final future = context.read<AdminProvider>().refreshDashboard();
    setState(() {
      _future = future;
    });
    return future;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _muat,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'Halo, ${auth.user?.displayName ?? 'Admin'}',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              formatTanggal(DateTime.now()),
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FutureBuilder<AdminDashboard>(
              future: _future,
              builder: (context, snap) {
                final data = snap.data;
                if (snap.connectionState != ConnectionState.done ||
                    data == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.6,
                      children: [
                        StatCard(
                          label: 'Hadir hari ini',
                          value: '${data.hadir}',
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        StatCard(
                          label: 'Terlambat',
                          value: '${data.terlambat}',
                          icon: Icons.schedule,
                          color: Colors.orange,
                        ),
                        StatCard(
                          label: 'Belum pulang',
                          value: '${data.belumPulang}',
                          icon: Icons.hourglass_bottom,
                          color: Colors.blueGrey,
                        ),
                        StatCard(
                          label: 'Tidak hadir',
                          value: '${data.tidakHadir}',
                          icon: Icons.person_off_outlined,
                          color: Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bar_chart),
                                const SizedBox(width: 8),
                                Text(
                                  'Kehadiran 7 hari terakhir',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            WeekBarChart(
                              counts: [
                                for (final e in data.minggu) e.value,
                              ],
                              todayIndex: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const QrGeneratorScreen(),
                                ),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Icon(Icons.qr_code_2, size: 32),
                                    SizedBox(height: 6),
                                    Text(
                                      'QR Absen',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ScanMemberScreen(),
                                ),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Icon(Icons.crop_free, size: 32),
                                    SizedBox(height: 6),
                                    Text(
                                      'Pindai Anggota',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Anggota aktif: ${data.totalAnggota} · '
                      'Pulang awal: ${data.pulangAwal} · '
                      'Lembur: ${data.lembur}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
