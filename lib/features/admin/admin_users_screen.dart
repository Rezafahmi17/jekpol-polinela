import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/auth_provider.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _key = GlobalKey<AsyncPageState>();
  String _role = '';
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _reload() {
    _key.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isSuper = auth.user?.isSuperAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Pengguna'),
        actions: [
          if (isSuper)
            IconButton(
              tooltip: 'Tambah Akun Baru',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () => _createUser(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _q,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _reload(),
              decoration: InputDecoration(
                hintText: 'Cari nama, NPM, atau email...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _q.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _q.clear();
                          _reload();
                        },
                      )
                    : null,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              for (final r in const [
                ('', 'Semua'),
                ('customer', 'Customer'),
                ('driver', 'Driver'),
                ('admin', 'Admin'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(r.$2),
                    selected: _role == r.$1,
                    selectedColor: AppColors.primaryLight,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _role == r.$1 ? AppColors.primaryDark : AppColors.grey,
                    ),
                    onSelected: (_) {
                      setState(() => _role = r.$1);
                      _reload();
                    },
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: AsyncPage(
              key: _key,
              load: () => Api.get('admin/users', query: {
                if (_role.isNotEmpty) 'role': _role,
                if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(),
              }),
              builder: (context, data) {
                final users = (data['users'] as List).map((e) => AppUser.fromJson(e)).toList();

                if (users.isEmpty) {
                  return const EmptyScroll(
                    icon: Icons.person_off_rounded,
                    title: 'Tidak ada pengguna ditemukan',
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final u = users[i];
                    return Card(
                      child: ListTile(
                        leading: Avatar(u.initials, size: 44),
                        title: Row(children: [
                          Expanded(
                            child: Text(u.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          StatusChip(
                            u.isBlocked ? 'Diblokir' : u.roleLabel,
                            u.isBlocked
                                ? AppColors.danger
                                : (u.role == 'driver' ? AppColors.primary : AppColors.info),
                          ),
                        ]),
                        subtitle: Text(
                          '${u.npm != null ? "NPM: ${u.npm} • " : ""}${u.email}\nHP: ${u.phone}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.more_vert_rounded, color: AppColors.grey),
                        onTap: () => _manageUser(context, u, isSuper),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createUser(BuildContext context) async {
    String role = 'admin';
    final name = TextEditingController();
    final npm = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final pw = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool busy = false;
        return StatefulBuilder(builder: (ctx, setS) {
          return AlertDialog(
            title: const Text('Tambah Akun', style: TextStyle(fontWeight: FontWeight.w800)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Peran Akun'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin Operasional')),
                    DropdownMenuItem(value: 'customer', child: Text('Customer (Mahasiswa)')),
                  ],
                  onChanged: (v) => setS(() => role = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama Lengkap')),
                const SizedBox(height: 10),
                TextField(controller: npm, decoration: const InputDecoration(labelText: 'NPM (opsional)')),
                const SizedBox(height: 10),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 10),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nomor HP')),
                const SizedBox(height: 10),
                TextField(controller: pw, obscureText: true, decoration: const InputDecoration(labelText: 'Password (min. 6 karakter)')),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        setS(() => busy = true);
                        try {
                          await Api.post('admin/users', body: {
                            'role': role,
                            'name': name.text.trim(),
                            if (npm.text.trim().isNotEmpty) 'npm': npm.text.trim(),
                            'email': email.text.trim(),
                            'phone': phone.text.trim(),
                            'password': pw.text,
                          });
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          setS(() => busy = false);
                          if (ctx.mounted) showError(ctx, e);
                        }
                      },
                child: const Text('Buat Akun'),
              ),
            ],
          );
        });
      },
    );

    if (created == true && mounted) {
      showMsg(context, 'Akun baru berhasil dibuat!');
      _reload();
    }
  }

  void _manageUser(BuildContext context, AppUser u, bool isSuper) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              Row(children: [
                Avatar(u.initials, size: 50),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    Text('${u.roleLabel} • ${u.email}', style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                  ]),
                ),
              ]),
              const Divider(height: 24),
              if (isSuper && u.role != 'super_admin') ...[
                if (u.isBlocked)
                  ListTile(
                    leading: const Icon(Icons.lock_open_rounded, color: AppColors.success),
                    title: const Text('Buka Blokir Akun', style: TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await confirm(context, 'Buka Blokir?', 'Aktifkan kembali akun ${u.name}?');
                      if (ok) {
                        try {
                          await Api.post('admin/users/${u.id}/block', body: {'blocked': false, 'reset_points': true});
                          if (context.mounted) showMsg(context, 'Blokir akun dibuka');
                          _reload();
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        }
                      }
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.block_rounded, color: AppColors.danger),
                    title: const Text('Blokir Akun', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final reason = TextEditingController();
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text('Blokir Akun ${u.name}'),
                          content: TextField(
                            controller: reason,
                            decoration: const InputDecoration(labelText: 'Alasan pemblokiran'),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                            FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Blokir'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        try {
                          await Api.post('admin/users/${u.id}/block', body: {
                            'blocked': true,
                            'reason': reason.text.trim().isEmpty ? 'Diblokir oleh administrator' : reason.text.trim(),
                          });
                          if (context.mounted) showMsg(context, 'Akun berhasil diblokir');
                          _reload();
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        }
                      }
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.password_rounded, color: AppColors.primary),
                  title: const Text('Reset Password'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final pw = TextEditingController();
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text('Reset Password ${u.name}'),
                        content: TextField(
                          controller: pw,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password Baru (min. 6 karakter)'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Simpan')),
                        ],
                      ),
                    );
                    if (ok == true && pw.text.length >= 6) {
                      try {
                        await Api.post('admin/users/${u.id}/password', body: {'password': pw.text});
                        if (context.mounted) showMsg(context, 'Password pengguna berhasil direset');
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
                  title: const Text('Hapus Akun', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Data transaksi tetap disimpan untuk audit.'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await confirm(context, 'Hapus Akun?',
                        'Akun ${u.name} akan dinonaktifkan permanen dan dokumen identitas dihapus.',
                        confirmText: 'Hapus Permanen', danger: true);
                    if (ok) {
                      try {
                        await Api.post('admin/users/${u.id}/delete');
                        if (context.mounted) showMsg(context, 'Akun dihapus');
                        _reload();
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

