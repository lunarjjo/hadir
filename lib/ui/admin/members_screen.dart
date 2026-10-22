/// Kelola anggota: cari, tambah, detail (edit/reset/nonaktif/hapus).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hadir/core/result.dart';
import 'package:hadir/core/validation.dart';
import 'package:hadir/data/models/user.dart';
import 'package:hadir/state/admin_provider.dart';
import 'package:hadir/state/auth_provider.dart';
import 'package:hadir/ui/widgets/common.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _cariCtl = TextEditingController();
  String _query = '';
  bool _memuat = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  @override
  void dispose() {
    _cariCtl.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _memuat = true);
    await context.read<AdminProvider>().refreshMembers();
    if (mounted) setState(() => _memuat = false);
  }

  Future<void> _tambahAnggota() async {
    final admin = context.read<AdminProvider>();
    final username = TextEditingController();
    final nama = TextEditingController();
    final sandi = TextEditingController();
    String peran = 'member';
    final kunci = GlobalKey<FormState>();
    final hasil = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Form(
          key: kunci,
          child: AlertDialog(
            title: const Text('Tambah anggota'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: username,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    helperText: 'a-z 0-9 . _ -',
                  ),
                  validator: validateUsername,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: nama,
                  decoration: const InputDecoration(labelText: 'Nama tampilan'),
                  validator: validateDisplayName,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: sandi,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Kata sandi awal',
                  ),
                  validator: validatePassword,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: peran,
                  decoration: const InputDecoration(labelText: 'Peran'),
                  items: const [
                    DropdownMenuItem(value: 'member', child: Text('Anggota')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => v == null ? null : setDlg(() => peran = v),
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
      ),
    );
    if (hasil != true || !mounted) return;
    final r = await admin.addMember(
      username: username.text,
      displayName: nama.text,
      role: peran,
      password: sandi.text,
    );
    if (!mounted) return;
    switch (r) {
      case Ok():
        showAppSnack(context, 'Anggota ${username.text} ditambahkan.');
      case Err(:final error):
        showAppSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;
    final semua = admin.members;
    final data = _query.isEmpty
        ? semua
        : semua
            .where(
              (u) =>
                  u.username.toLowerCase().contains(_query) ||
                  u.displayName.toLowerCase().contains(_query),
            )
            .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-anggota',
        onPressed: _tambahAnggota,
        icon: const Icon(Icons.person_add),
        label: const Text('Anggota'),
      ),
      body: SafeArea(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Anggota (${semua.length})',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              controller: _cariCtl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Cari nama atau username',
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _cariCtl.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: _memuat
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                    ? EmptyState(
                        icon: Icons.group_off,
                        title: 'Tidak ada anggota',
                        subtitle: _query.isEmpty
                            ? 'Tambah anggota pertama dengan tombol +.'
                            : 'Tidak ada hasil untuk "$_query".',
                      )
                    : RefreshIndicator(
                        onRefresh: _muat,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                          itemCount: data.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final u = data[i];
                            final saya = u.id == auth.user?.id;
                            return Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: u.isAdmin
                                      ? cs.primaryContainer
                                      : cs.secondaryContainer,
                                  child: Text(
                                    avatarInitials(u.displayName),
                                    style: TextStyle(
                                      color: u.isAdmin
                                          ? cs.onPrimaryContainer
                                          : cs.onSecondaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        saya
                                            ? '${u.displayName} (Anda)'
                                            : u.displayName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    RoleChip(isAdmin: u.isAdmin),
                                  ],
                                ),
                                subtitle: Text(
                                  '@${u.username}'
                                  '${u.active ? '' : ' · nonaktif'}',
                                ),
                                trailing: u.active
                                    ? null
                                    : Icon(
                                        Icons.pause_circle_outline,
                                        color: cs.error,
                                      ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MemberDetailPage(userId: u.id),
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

class MemberDetailPage extends StatefulWidget {
  final String userId;

  const MemberDetailPage({super.key, required this.userId});

  @override
  State<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends State<MemberDetailPage> {
  Map<String, int> _statBulanan = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _muat());
  }

  Future<void> _muat() async {
    final stat = await context.read<AdminProvider>().memberMonthlyStats(
          widget.userId,
        );
    if (mounted) {
      setState(() => _statBulanan = stat);
    }
  }

  Future<void> _editAnggota(User u) async {
    final admin = context.read<AdminProvider>();
    final nama = TextEditingController(text: u.displayName);
    String peran = u.role;
    bool aktif = u.active;
    final kunci = GlobalKey<FormState>();
    final hasil = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Form(
          key: kunci,
          child: AlertDialog(
            title: const Text('Edit anggota'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nama,
                  decoration: const InputDecoration(labelText: 'Nama tampilan'),
                  validator: validateDisplayName,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: peran,
                  decoration: const InputDecoration(labelText: 'Peran'),
                  items: const [
                    DropdownMenuItem(value: 'member', child: Text('Anggota')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => v == null ? null : setDlg(() => peran = v),
                ),
                SwitchListTile(
                  value: aktif,
                  onChanged: (v) => setDlg(() => aktif = v),
                  title: const Text('Akun aktif'),
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
      ),
    );
    if (hasil != true || !mounted) return;
    final r = await admin.updateMember(
      u.copyWith(displayName: nama.text.trim(), role: peran, active: aktif),
    );
    if (!mounted) return;
    switch (r) {
      case Ok():
        showAppSnack(context, 'Profil anggota diperbarui.');
        _muat();
      case Err(:final error):
        showAppSnack(context, error.message, isError: true);
    }
  }

  Future<void> _resetSandi(User u) async {
    final admin = context.read<AdminProvider>();
    final sandi = TextEditingController();
    final kunci = GlobalKey<FormState>();
    final hasil = await showDialog<bool>(
      context: context,
      builder: (ctx) => Form(
        key: kunci,
        child: AlertDialog(
          title: Text('Reset sandi @${u.username}'),
          content: TextFormField(
            controller: sandi,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Kata sandi baru',
              helperText: 'Minimal 6 karakter',
            ),
            validator: validatePassword,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (kunci.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
    if (hasil != true || !mounted) return;
    final r = await admin.resetPassword(u.id, sandi.text);
    if (!mounted) return;
    switch (r) {
      case Ok():
        showAppSnack(context, 'Sandi @${u.username} direset.');
      case Err(:final error):
        showAppSnack(context, error.message, isError: true);
    }
  }

  Future<void> _hapus(User u) async {
    final admin = context.read<AdminProvider>();
    final ya = await confirmDialog(
      context,
      title: 'Hapus @${u.username}?',
      message:
          'Penghapusan permanen. Anggota dengan riwayat absensi tidak bisa '
          'dihapus — nonaktifkan saja.',
      confirmLabel: 'Hapus',
      danger: true,
    );
    if (!ya || !mounted) return;
    final r = await admin.deleteMember(u.id);
    if (!mounted) return;
    switch (r) {
      case Ok():
        showAppSnack(context, 'Anggota dihapus.');
        Navigator.pop(context);
      case Err(:final error):
        showAppSnack(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final auth = context.watch<AuthProvider>();
    final u = admin.members.where((m) => m.id == widget.userId).firstOrNull;
    final cs = Theme.of(context).colorScheme;

    if (u == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail anggota')),
        body: const EmptyState(
          icon: Icons.person_off,
          title: 'Anggota tidak ditemukan',
          subtitle: 'Mungkin sudah dihapus.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(u.displayName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: u.isAdmin
                        ? cs.primaryContainer
                        : cs.secondaryContainer,
                    child: Text(
                      avatarInitials(u.displayName),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: u.isAdmin
                            ? cs.onPrimaryContainer
                            : cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    u.displayName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '@${u.username}',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RoleChip(isAdmin: u.isAdmin),
                      const SizedBox(width: 8),
                      if (!u.active)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(999),
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
                  ),
                  if (u.id == auth.user?.id)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Ini akun kamu sendiri.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bulan ini',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      const StatusBadge(status: 'hadir'),
                      Text('${_statBulanan['hadir'] ?? 0}'),
                      const StatusBadge(status: 'terlambat'),
                      Text('${_statBulanan['terlambat'] ?? 0}'),
                      const StatusBadge(status: 'pulang_awal'),
                      Text('${_statBulanan['pulang_awal'] ?? 0}'),
                      const StatusBadge(status: 'lembur'),
                      Text('${_statBulanan['lembur'] ?? 0}'),
                    ],
                  ),
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
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit profil'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editAnggota(u),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Reset kata sandi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _resetSandi(u),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: cs.error,
                  ),
                  title: Text(
                    'Hapus permanen',
                    style: TextStyle(color: cs.error),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _hapus(u),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
