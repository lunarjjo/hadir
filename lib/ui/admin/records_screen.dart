/// Rekap absensi: filter lengkap, detail, ekspor CSV, absen manual.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hadir/core/attendance_rules.dart';
import 'package:hadir/core/datetime_format.dart';
import 'package:hadir/core/geo.dart';
import 'package:hadir/core/result.dart';
import 'package:hadir/data/models/attendance.dart';
import 'package:hadir/data/models/office.dart';
import 'package:hadir/data/models/user.dart';
import 'package:hadir/state/admin_provider.dart';
import 'package:hadir/ui/widgets/common.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  int _rentang = 1; // 0 hari ini, 1 tujuh hari, 2 tiga puluh hari
  String? _status;
  String? _userId;
  String? _officeId;
  List<Attendance> _data = [];
  List<User> _anggota = const [];
  List<Office> _kantor = const [];
  bool _memuat = true;

  static const _statusOpsi = <({String value, String label})>[
    (value: '', label: 'Semua status'),
    (value: 'hadir', label: 'Hadir'),
    (value: 'terlambat', label: 'Terlambat'),
    (value: 'pulang_awal', label: 'Pulang Awal'),
    (value: 'lembur', label: 'Lembur'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _muatSemua());
  }

  Future<void> _muatSemua() async {
    final admin = context.read<AdminProvider>();
    final anggota = await admin.refreshMembers();
    final kantor = await admin.refreshOffices();
    if (!mounted) return;
    setState(() {
      _anggota = anggota;
      _kantor = kantor;
    });
    await _muat();
  }

  (String, String) _rentangHari() {
    final now = DateTime.now();
    switch (_rentang) {
      case 0:
        return (dayKey(now), dayKey(now));
      case 2:
        return (
          dayKey(now.subtract(const Duration(days: 29))),
          dayKey(now),
        );
      default:
        return (
          dayKey(now.subtract(const Duration(days: 6))),
          dayKey(now),
        );
    }
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    final admin = context.read<AdminProvider>();
    final (dari, sampai) = _rentangHari();
    final data = await admin.loadRecords(
      fromDay: dari,
      toDay: sampai,
      userId: (_userId?.isEmpty ?? true) ? null : _userId,
      officeId: (_officeId?.isEmpty ?? true) ? null : _officeId,
      status: (_status?.isEmpty ?? true) ? null : _status,
    );
    if (!mounted) return;
    setState(() {
      _data = data;
      _memuat = false;
    });
  }

  Future<void> _ekspor() async {
    if (_data.isEmpty) {
      showAppSnack(context, 'Tidak ada data untuk diekspor.', isError: true);
      return;
    }
    final admin = context.read<AdminProvider>();
    final (dari, sampai) = _rentangHari();
    final namaFile = 'hadir-rekap-$dari-$sampai.csv';
    final r = await admin.exportCsv(_data, namaFile);
    if (!mounted) return;
    switch (r) {
      case Ok(:final value):
        await infoDialog(
          context,
          title: 'CSV tersimpan',
          icon: Icons.file_download_done,
          content: Text(
            'Berkas: $namaFile\n\nLokasi (folder dokumen aplikasi):\n'
            '$value\n\nSalin ke komputer lewat kabel data atau file manager.',
          ),
        );
      case Err(:final error):
        showAppSnack(context, error.message, isError: true);
    }
  }

  Future<void> _absenManual() async {
    if (_anggota.isEmpty) {
      showAppSnack(context, 'Tambahkan anggota dulu.', isError: true);
      return;
    }
    if (_kantor.where((o) => o.active).isEmpty) {
      showAppSnack(context, 'Tambahkan kantor aktif dulu.', isError: true);
      return;
    }
    final admin = context.read<AdminProvider>();
    final kunci = GlobalKey<FormState>();
    String userId = _anggota.first.id;
    String officeId = _kantor.firstWhere((o) => o.active).id;
    DateTime tanggal = DateTime.now();
    TimeOfDay jamMasuk = TimeOfDay.now();
    bool pakaiPulang = false;
    TimeOfDay jamPulang = TimeOfDay(
      hour: TimeOfDay.now().hour,
      minute: TimeOfDay.now().minute,
    );
    final catatan = TextEditingController();

    final hasil = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Form(
          key: kunci,
          child: AlertDialog(
            title: const Text('Absen manual'),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: userId,
                      decoration: const InputDecoration(labelText: 'Anggota'),
                      items: [
                        for (final u in _anggota)
                          DropdownMenuItem(
                            value: u.id,
                            child: Text(
                              '${u.displayName} (@${u.username})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) =>
                          v == null ? null : setDlg(() => userId = v),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: officeId,
                      decoration: const InputDecoration(labelText: 'Kantor'),
                      items: [
                        for (final o in _kantor.where((o) => o.active))
                          DropdownMenuItem(
                            value: o.id,
                            child: Text(o.name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) =>
                          v == null ? null : setDlg(() => officeId = v),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final p = await showDatePicker(
                          context: ctx,
                          initialDate: tanggal,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (p != null) setDlg(() => tanggal = p);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal',
                          suffixIcon: Icon(Icons.event),
                        ),
                        child: Text(formatTanggalSingkat(tanggal)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final p = await showTimePicker(
                          context: ctx,
                          initialTime: jamMasuk,
                        );
                        if (p != null) setDlg(() => jamMasuk = p);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Jam masuk',
                          suffixIcon: Icon(Icons.login),
                        ),
                        child: Text(jamMasuk.format(ctx)),
                      ),
                    ),
                    CheckboxListTile(
                      value: pakaiPulang,
                      onChanged: (v) =>
                          setDlg(() => pakaiPulang = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Isi jam pulang juga'),
                    ),
                    if (pakaiPulang)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          final p = await showTimePicker(
                            context: ctx,
                            initialTime: jamPulang,
                          );
                          if (p != null) setDlg(() => jamPulang = p);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Jam pulang',
                            suffixIcon: Icon(Icons.logout),
                          ),
                          child: Text(jamPulang.format(ctx)),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: catatan,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (opsional)',
                      ),
                    ),
                  ],
                ),
              ),
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
      ),
    );
    if (hasil != true || !mounted) return;

    DateTime bersihkanJam(TimeOfDay t) =>
        DateTime(tanggal.year, tanggal.month, tanggal.day, t.hour, t.minute);
    // Jam pulang sebelum jam masuk → dianggap hari berikutnya (shift malam).
    DateTime jamPulangFix = bersihkanJam(jamPulang);
    if (pakaiPulang && jamPulangFix.isBefore(bersihkanJam(jamMasuk))) {
      jamPulangFix = jamPulangFix.add(const Duration(days: 1));
    }

    final r = await admin.manualMark(
      userId: userId,
      officeId: officeId,
      checkIn: bersihkanJam(jamMasuk),
      checkOut: pakaiPulang ? jamPulangFix : null,
      note: catatan.text.trim().isEmpty ? null : catatan.text.trim(),
    );
    if (!mounted) return;
    switch (r) {
      case Ok():
        showAppSnack(context, 'Absen manual dicatat.');
        _muat();
      case Err(:final error):
        showAppSnack(context, error.message, isError: true);
    }
  }

  void _detail(Attendance r) {
    User? user;
    for (final u in _anggota) {
      if (u.id == r.userId) user = u;
    }
    Office? office;
    for (final o in _kantor) {
      if (o.id == r.officeId) office = o;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _LembarDetail(
        rekaman: r,
        user: user,
        office: office,
        onNoteChanged: (note) async {
          await context.read<AdminProvider>().updateRecordNote(r.id, note);
          if (ctx.mounted) Navigator.pop(ctx);
          if (mounted) {
            showAppSnack(context, 'Catatan diperbarui.');
            _muat();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-manual',
        onPressed: _absenManual,
        icon: const Icon(Icons.edit_calendar),
        label: const Text('Absen Manual'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rekap Absensi',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ekspor CSV',
                    onPressed: _ekspor,
                    icon: const Icon(Icons.file_download_outlined),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Hari ini')),
                  ButtonSegment(value: 1, label: Text('7 hari')),
                  ButtonSegment(value: 2, label: Text('30 hari')),
                ],
                selected: {_rentang},
                onSelectionChanged: (s) {
                  setState(() => _rentang = s.first);
                  _muat();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      value: _status ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        isDense: true,
                      ),
                      items: [
                        for (final s in _statusOpsi)
                          DropdownMenuItem(value: s.value, child: Text(s.label)),
                      ],
                      onChanged: (v) {
                        setState(() => _status = v);
                        _muat();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      value: _officeId ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Kantor',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('Semua kantor')),
                        for (final o in _kantor)
                          DropdownMenuItem(value: o.id, child: Text(o.name)),
                      ],
                      onChanged: (v) {
                        setState(() => _officeId = v);
                        _muat();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      value: _userId ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Anggota',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('Semua anggota')),
                        for (final u in _anggota)
                          DropdownMenuItem(
                            value: u.id,
                            child: Text(
                              u.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        setState(() => _userId = v);
                        _muat();
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _memuat
                  ? const Center(child: CircularProgressIndicator())
                  : _data.isEmpty
                      ? const EmptyState(
                          icon: Icons.playlist_remove,
                          title: 'Tidak ada rekaman',
                          subtitle:
                              'Coba ubah rentang waktu atau filter di atas.',
                        )
                      : RefreshIndicator(
                          onRefresh: _muat,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                            itemCount: _data.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) =>
                                _kartu(context, cs, _data[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartu(BuildContext context, ColorScheme cs, Attendance r) {
    User? user;
    for (final u in _anggota) {
      if (u.id == r.userId) user = u;
    }
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.secondaryContainer,
          child: Text(
            avatarInitials(user?.displayName ?? '?'),
            style: TextStyle(color: cs.onSecondaryContainer),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user?.displayName ?? r.userId,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (r.isManual) ...[
              const SizedBox(width: 6),
              const StatusBadge(status: 'manual'),
            ],
          ],
        ),
        subtitle: Text(
          '${formatTanggalSingkat(r.checkInAt)} · '
          'masuk ${formatJam(r.checkInAt)}'
          '${r.checkOutAt == null ? '' : ' · pulang ${formatJam(r.checkOutAt!)}'}'
          '${r.workedMinutes == null ? '' : ' · ${formatDurasi(r.workedMinutes)}'}',
        ),
        trailing: StatusBadge(status: r.status),
        onTap: () => _detail(r),
      ),
    );
  }
}

class _LembarDetail extends StatefulWidget {
  final Attendance rekaman;
  final User? user;
  final Office? office;
  final Future<void> Function(String? note) onNoteChanged;

  const _LembarDetail({
    required this.rekaman,
    required this.user,
    required this.office,
    required this.onNoteChanged,
  });

  @override
  State<_LembarDetail> createState() => _LembarDetailState();
}

class _LembarDetailState extends State<_LembarDetail> {
  late final TextEditingController _catatan;

  @override
  void initState() {
    super.initState();
    _catatan = TextEditingController(text: widget.rekaman.note ?? '');
  }

  @override
  void dispose() {
    _catatan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rekaman;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.user?.displayName ?? r.userId,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              StatusBadge(status: r.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatTanggal(r.checkInAt)} · '
            'metode ${r.isManual ? 'manual' : 'QR'}',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const Divider(height: 24),
          _baris('Kantor', widget.office?.name ?? '—'),
          _baris('Masuk', formatJamDetik(r.checkInAt)),
          _baris(
            'Jarak saat masuk',
            '${formatDistance(r.checkInDistance)} '
            '(${r.checkInGeoOk ? 'dalam radius' : 'luar radius'})',
          ),
          _baris('Token QR', r.tokenOk ? 'valid' : 'tanpa QR'),
          if (r.checkOutAt != null) ...[
            _baris('Pulang', formatJamDetik(r.checkOutAt!)),
            _baris(
              'Jarak saat pulang',
              r.checkOutDistance == null
                  ? '—'
                  : '${formatDistance(r.checkOutDistance!)} '
                      '(${r.checkOutGeoOk == true ? 'dalam radius' : 'luar radius'})',
            ),
            _baris('Durasi kerja', formatDurasi(r.workedMinutes)),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _catatan,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Catatan admin',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () =>
                widget.onNoteChanged(_catatan.text.trim().isEmpty
                    ? null
                    : _catatan.text.trim()),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Simpan catatan'),
          ),
        ],
      ),
    );
  }

  Widget _baris(String label, String nilai) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(nilai)),
        ],
      ),
    );
  }
}
