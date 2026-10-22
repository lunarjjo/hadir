/// Generator QR absen: rotasi 1 menit / sesi 5 menit / seharian
/// + pengaturan kebijakan (wajib QR, jam kerja, tenggang).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:hadir/data/models/office.dart';
import 'package:hadir/state/admin_provider.dart';
import 'package:hadir/state/settings_provider.dart';
import 'package:hadir/ui/widgets/common.dart';

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  String? _officeId;
  int _modeDetik = 300;
  Timer? _timer;
  String _token = '';

  static const List<({int detik, String label})> _modes = [
    (detik: 60, label: 'Rotasi 1 mnt'),
    (detik: 300, label: 'Sesi 5 mnt'),
    (detik: 43200, label: 'Seharian'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _siapkan());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _siapkan() async {
    final admin = context.read<AdminProvider>();
    final offices = await admin.refreshOffices(activeOnly: true);
    if (!mounted) return;
    setState(() {
      _officeId = _officeId ?? (offices.isEmpty ? null : offices.first.id);
    });
    _token = _hitungToken();
    _mulaiTimer();
  }

  Office? get _kantorTerpilih {
    for (final o in context.read<AdminProvider>().offices) {
      if (o.id == _officeId) return o;
    }
    return null;
  }

  String _hitungToken() {
    final kantor = _kantorTerpilih;
    if (kantor == null) return '';
    return context.read<AdminProvider>().generateOfficeQr(
          kantor,
          _modeDetik,
        );
  }

  void _mulaiTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final tokenBaru = _hitungToken();
      if (tokenBaru != _token) {
        setState(() => _token = tokenBaru);
      } else if (_modeDetik == 60) {
        // Tetap rebuild untuk menghitung mundur.
        setState(() {});
      }
    });
  }

  int get _detikTersisa {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return _modeDetik - (now % _modeDetik);
  }

  Future<void> _ubahMode(int detik) async {
    setState(() {
      _modeDetik = detik;
      _token = _hitungToken();
    });
    _mulaiTimer();
  }

  Future<void> _aturKebijakan() async {
    final settings = context.read<SettingsProvider>();
    final s = settings.settings;
    final mulaiCtl = TextEditingController();
    final pulangCtl = TextEditingController();
    final telatCtl = TextEditingController(text: s.lateGraceMinutes.toString());
    final awalCtl = TextEditingController(text: s.earlyLeaveGraceMinutes.toString());
    final lemburCtl = TextEditingController(text: s.overtimeExtraMinutes.toString());
    String labelJam(int menit) =>
        '${(menit ~/ 60).toString().padLeft(2, '0')}:'
        '${(menit % 60).toString().padLeft(2, '0')}';
    mulaiCtl.text = labelJam(s.workStartMinutes);
    pulangCtl.text = labelJam(s.workEndMinutes);
    final kunci = GlobalKey<FormState>();
    final hasil = await showDialog<bool>(
      context: context,
      builder: (ctx) => Form(
        key: kunci,
        child: AlertDialog(
          title: const Text('Jam kerja & kebijakan'),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: mulaiCtl,
                    decoration: const InputDecoration(
                      labelText: 'Jam mulai kerja (HH:mm)',
                    ),
                    validator: (v) =>
                        _parseJam(v) == null ? 'Format HH:mm, mis. 08:00' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: pulangCtl,
                    decoration: const InputDecoration(
                      labelText: 'Jam pulang kerja (HH:mm)',
                    ),
                    validator: (v) =>
                        _parseJam(v) == null ? 'Format HH:mm, mis. 17:00' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: telatCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tenggang telat (menit)',
                    ),
                    validator: _validasiMenit,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: awalCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tenggang pulang awal (menit)',
                    ),
                    validator: _validasiMenit,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: lemburCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ambang lembur di atas hari penuh (menit)',
                    ),
                    validator: _validasiMenit,
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
    final mulai = _parseJam(mulaiCtl.text)!;
    final pulang = _parseJam(pulangCtl.text)!;
    if (pulang <= mulai) {
      showAppSnack(
        context,
        'Jam pulang harus setelah jam mulai.',
        isError: true,
      );
      return;
    }
    await settings.updateSettings(
      s.copyWith(
        workStartMinutes: mulai,
        workEndMinutes: pulang,
        lateGraceMinutes: int.parse(telatCtl.text.trim()),
        earlyLeaveGraceMinutes: int.parse(awalCtl.text.trim()),
        overtimeExtraMinutes: int.parse(lemburCtl.text.trim()),
      ),
    );
    if (mounted) showAppSnack(context, 'Kebijakan jam kerja tersimpan.');
  }

  static int? _parseJam(String? v) {
    final bagian = (v ?? '').trim().split(':');
    if (bagian.length != 2) return null;
    final jam = int.tryParse(bagian[0]);
    final menit = int.tryParse(bagian[1]);
    if (jam == null || menit == null) return null;
    if (jam < 0 || jam > 23 || menit < 0 || menit > 59) return null;
    return jam * 60 + menit;
  }

  static String? _validasiMenit(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null || n < 0 || n > 240) {
      return 'Isi 0–240 menit.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final settings = context.watch<SettingsProvider>();
    final offices = admin.offices;
    final cs = Theme.of(context).colorScheme;
    final kantor = _kantorTerpilih;

    return Scaffold(
      appBar: AppBar(title: const Text('QR Absen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (offices.isEmpty)
            const EmptyState(
              icon: Icons.location_off,
              title: 'Belum ada kantor aktif',
              subtitle: 'Tambahkan kantor dulu di tab Kantor.',
            )
          else ...[
            DropdownButtonFormField<String>(
              value: _officeId,
              decoration: const InputDecoration(
                labelText: 'Kantor',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              items: [
                for (final o in offices)
                  DropdownMenuItem(value: o.id, child: Text(o.name)),
              ],
              onChanged: (v) {
                setState(() {
                  _officeId = v;
                  _token = _hitungToken();
                });
              },
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: [
                for (final m in _modes)
                  ButtonSegment(value: m.detik, label: Text(m.label)),
              ],
              selected: {_modeDetik},
              onSelectionChanged: (s) => _ubahMode(s.first),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    child: QrImageView(
                      data: _token,
                      version: QrVersions.auto,
                      size: 272,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF000000),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_modeDetik == 60) ...[
                    Text(
                      'Token baru dalam $_detikTersisa detik',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: LinearProgressIndicator(
                        value: _detikTersisa / _modeDetik,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ] else
                    Text(
                      switch (_modeDetik) {
                        43200 => 'Token berlaku seharian untuk hari ini.',
                        _ => 'Token berlaku 5 menit per sesi.',
                      },
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Tampilkan layar ini di meja depan. Anggota memindai QR ini '
                  'saat absen — posisi GPS mereka otomatis diperiksa terhadap '
                  'kantor ${kantor?.name ?? '-'}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.qr_code_scanner_outlined),
                  value: settings.settings.requireQr,
                  onChanged: (v) => settings.updateSettings(
                        settings.settings.copyWith(requireQr: v),
                      ),
                  title: const Text('Wajib QR saat absen'),
                  subtitle: const Text(
                    'Jika nonaktif, anggota cukup berada dalam radius kantor',
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Jam kerja & kebijakan'),
                  subtitle: Text(
                    'Mulai ${_labelMenit(settings.settings.workStartMinutes)} · '
                    'pulang ${_labelMenit(settings.settings.workEndMinutes)} · '
                    'tenggang ${settings.settings.lateGraceMinutes} mnt',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _aturKebijakan,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _labelMenit(int menit) =>
      '${(menit ~/ 60).toString().padLeft(2, '0')}:'
      '${(menit % 60).toString().padLeft(2, '0')}';
}
