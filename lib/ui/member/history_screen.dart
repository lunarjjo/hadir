/// Riwayat absensi pribadi dengan navigasi bulan + filter status.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hadir/core/datetime_format.dart';
import 'package:hadir/data/models/attendance.dart';
import 'package:hadir/state/member_provider.dart';
import 'package:hadir/ui/widgets/common.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _bulan = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _filter;
  List<Attendance> _semua = [];
  bool _memuat = true;

  static const List<({String value, String label})> _filters = [
    (value: '', label: 'Semua'),
    (value: 'hadir', label: 'Hadir'),
    (value: 'terlambat', label: 'Terlambat'),
    (value: 'pulang_awal', label: 'Pulang Awal'),
    (value: 'lembur', label: 'Lembur'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final member = context.read<MemberProvider>();
    final awal = DateTime(_bulan.year, _bulan.month, 1);
    final akhir = DateTime(_bulan.year, _bulan.month + 1, 0, 23, 59, 59);
    final data = await member.historyRange(awal, akhir);
    if (!mounted) return;
    setState(() {
      _semua = data;
      _memuat = false;
    });
  }

  void _geserBulan(int delta) {
    setState(() {
      _bulan = DateTime(_bulan.year, _bulan.month + delta, 1);
    });
    _muat();
  }

  List<Attendance> get _tersaring =>
      (_filter == null || _filter!.isEmpty)
          ? _semua
          : _semua.where((r) => r.status == _filter).toList();

  @override
  Widget build(BuildContext context) {
    final data = _tersaring;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Riwayat Absen',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _geserBulan(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      formatBulanTahun(_bulan),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _geserBulan(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: (_filter ?? '') == f.value,
                      label: Text(f.label),
                      onSelected: (_) =>
                          setState(() => _filter = f.value),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _memuat
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                    ? EmptyState(
                        icon: Icons.event_busy,
                        title: 'Belum ada absensi',
                        subtitle:
                            'Tidak ada rekaman pada bulan '
                            '${formatBulanTahun(_bulan)}.',
                      )
                    : RefreshIndicator(
                        onRefresh: _muat,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          itemCount: data.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _kartu(context, data[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _kartu(BuildContext context, Attendance r) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${r.checkInAt.day}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    kBulanSingkat[r.checkInAt.month - 1],
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Masuk ${formatJam(r.checkInAt)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      if (r.isManual) const StatusBadge(status: 'manual'),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.checkOutAt == null
                        ? 'Belum pulang'
                        : 'Pulang ${formatJam(r.checkOutAt!)} · '
                            '${formatDurasi(r.workedMinutes)}',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge(status: r.status),
          ],
        ),
      ),
    );
  }
}
