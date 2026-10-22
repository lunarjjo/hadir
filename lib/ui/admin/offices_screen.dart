/// Kelola kantor: CRUD + ambil koordinat dari GPS.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hadir/core/result.dart';
import 'package:hadir/core/validation.dart';
import 'package:hadir/data/models/office.dart';
import 'package:hadir/state/admin_provider.dart';
import 'package:hadir/state/app_bootstrap.dart';
import 'package:hadir/ui/widgets/common.dart';

class OfficesScreen extends StatefulWidget {
  const OfficesScreen({super.key});

  @override
  State<OfficesScreen> createState() => _OfficesScreenState();
}

class _OfficesScreenState extends State<OfficesScreen> {
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    await context.read<AdminProvider>().refreshOffices();
    if (mounted) setState(() => _memuat = false);
  }

  Future<void> _hapus(Office o) async {
    final admin = context.read<AdminProvider>();
    final ya = await confirmDialog(
      context,
      title: 'Hapus ${o.name}?',
      message:
          'Kantor dengan riwayat absensi tidak bisa dihapus — '
          'nonaktifkan saja agar tidak dipakai absen baru.',
      confirmLabel: 'Hapus',
      danger: true,
    );
    if (!ya || !mounted) return;
    final r = await admin.deleteOffice(o.id);
    if (!mounted) return;
    switch (r) {
      case Ok():
        showAppSnack(context, 'Kantor dihapus.');
      case Err(:final error):
        showAppSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final cs = Theme.of(context).colorScheme;
    final data = admin.offices;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-kantor',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OfficeEditorPage()),
        ),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Kantor'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Kantor (${data.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: _memuat
                  ? const Center(child: CircularProgressIndicator())
                  : data.isEmpty
                      ? const EmptyState(
                          icon: Icons.location_off,
                          title: 'Belum ada kantor',
                          subtitle:
                              'Tambahkan lokasi kantor beserta radius absen.',
                        )
                      : RefreshIndicator(
                          onRefresh: _muat,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                            itemCount: data.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final o = data[i];
                              return Card(
                                margin: EdgeInsets.zero,
                                child: ListTile(
                                  leading: Icon(
                                    o.active
                                        ? Icons.place
                                        : Icons.place_outlined,
                                    color: o.active
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                  title: Row(
                                    children: [
                                      Flexible(child: Text(o.name)),
                                      if (!o.active) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cs.errorContainer,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'Nonaktif',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: cs.onErrorContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${o.latitude.toStringAsFixed(5)}, '
                                    '${o.longitude.toStringAsFixed(5)} · '
                                    'radius ${o.radiusMeters} m',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Hapus',
                                        onPressed: () => _hapus(o),
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: cs.error,
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          OfficeEditorPage(office: o),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfficeEditorPage extends StatefulWidget {
  final Office? office;

  const OfficeEditorPage({super.key, this.office});

  @override
  State<OfficeEditorPage> createState() => _OfficeEditorPageState();
}

class _OfficeEditorPageState extends State<OfficeEditorPage> {
  final _kunci = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _radius;
  late bool _aktif;
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    final o = widget.office;
    _nama = TextEditingController(text: o?.name ?? '');
    _lat = TextEditingController(
      text: o == null ? '' : o.latitude.toStringAsFixed(6),
    );
    _lng = TextEditingController(
      text: o == null ? '' : o.longitude.toStringAsFixed(6),
    );
    _radius = TextEditingController(text: '${o?.radiusMeters ?? 100}');
    _aktif = o?.active ?? true;
  }

  @override
  void dispose() {
    _nama.dispose();
    _lat.dispose();
    _lng.dispose();
    _radius.dispose();
    super.dispose();
  }

  Future<void> _pakaiLokasiSekarang() async {
    final bootstrap = context.read<AppBootstrap>();
    final r = await bootstrap.location.getCurrent();
    if (!mounted) return;
    switch (r) {
      case Ok(:final value):
        setState(() {
          _lat.text = value.latitude.toStringAsFixed(6);
          _lng.text = value.longitude.toStringAsFixed(6);
        });
        showAppSnack(context, 'Koordinat terisi dari GPS.');
      case Err(:final error):
        showAppSnack(context, error.message, isError: true);
    }
  }

  Future<void> _simpan() async {
    if (_sibuk || !_kunci.currentState!.validate()) return;
    setState(() => _sibuk = true);
    final admin = context.read<AdminProvider>();
    final r = await admin.saveOffice(
      id: widget.office?.id,
      name: _nama.text,
      latitude: tryParseDouble(_lat.text)!,
      longitude: tryParseDouble(_lng.text)!,
      radiusMeters: int.parse(_radius.text.trim()),
      active: _aktif,
    );
    if (!mounted) return;
    setState(() => _sibuk = false);
    switch (r) {
      case Ok():
        Navigator.pop(context);
        showAppSnack(context, 'Kantor tersimpan.');
      case Err(:final error):
        showAppSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.office == null ? 'Kantor baru' : 'Edit kantor'),
      ),
      body: Form(
        key: _kunci,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nama,
              decoration: const InputDecoration(
                labelText: 'Nama kantor',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              validator: validateOfficeName,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _lat,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: const InputDecoration(
                labelText: 'Latitude',
                prefixIcon: Icon(Icons.south_outlined),
                helperText: 'Rentang -90 s.d. 90',
              ),
              validator: validateLatitude,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _lng,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: const InputDecoration(
                labelText: 'Longitude',
                prefixIcon: Icon(Icons.east_outlined),
                helperText: 'Rentang -180 s.d. 180',
              ),
              validator: validateLongitude,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _radius,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Radius absen (meter)',
                prefixIcon: Icon(Icons.radio_button_checked),
                helperText: '10–5000 meter',
              ),
              validator: validateRadiusMeters,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pakaiLokasiSekarang,
                icon: const Icon(Icons.my_location),
                label: const Text('Gunakan lokasi saat ini'),
              ),
            ),
            SwitchListTile(
              value: _aktif,
              onChanged: (v) => setState(() => _aktif = v),
              title: const Text('Kantor aktif'),
              subtitle: const Text('Kantor nonaktif tak bisa dipakai absen'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _simpan,
              icon: _sibuk
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Simpan kantor'),
            ),
          ],
        ),
      ),
    );
  }
}
