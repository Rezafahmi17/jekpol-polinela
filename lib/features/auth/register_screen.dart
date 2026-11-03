import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/auth_provider.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  String _role = 'customer';
  final _name = TextEditingController();
  final _npm = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _vehicle = TextEditingController();
  final _plate = TextEditingController();
  final _color = TextEditingController();
  XFile? _ktm;
  XFile? _surat;
  bool _obscure = true;

  @override
  void dispose() {
    for (final c in [_name, _npm, _email, _phone, _pw, _pw2, _vehicle, _plate, _color]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(bool ktm) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SheetHandle(),
            ListTile(leading: const Icon(Icons.photo_camera_rounded), title: const Text('Ambil foto'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('Pilih dari galeri'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
          ]),
        ),
      ),
    );
    if (source == null) return;
    try {
      final f = await ImagePicker().pickImage(source: source, maxWidth: 1800, imageQuality: 85);
      if (f != null) setState(() => ktm ? _ktm = f : _surat = f);
    } catch (e) {
      if (mounted) showMsg(context, 'Tidak dapat mengambil gambar: $e', error: true);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_role == 'driver' && (_ktm == null || _surat == null)) {
      showMsg(context, 'Foto KTM dan surat pernyataan bermeterai wajib diunggah', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    try {
      final msg = await context.read<AuthProvider>().register(
        {
          'role': _role,
          'name': _name.text.trim(),
          'npm': _npm.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'password': _pw.text,
          if (_role == 'driver') ...{
            'vehicle_model': _vehicle.text.trim(),
            'plate_number': _plate.text.trim(),
            'vehicle_color': _color.text.trim(),
          },
        },
        files: _role == 'driver' ? {'ktm': _ktm!.path, 'surat': _surat!.path} : const {},
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      showMsg(context, msg);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  String? _req(String? v, [String label = 'Kolom ini']) => (v == null || v.trim().isEmpty) ? '$label wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    final isDriver = _role == 'driver';
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Akun')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Daftar sebagai', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.grey)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _roleCard('customer', Icons.person_rounded, 'Customer', 'Pesan ojek')),
                const SizedBox(width: 12),
                Expanded(child: _roleCard('driver', Icons.two_wheeler_rounded, 'Driver', 'Terima pesanan')),
              ]),
              const SizedBox(height: 20),
              TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nama lengkap', prefixIcon: Icon(Icons.badge_outlined)), validator: (v) => _req(v, 'Nama')),
              const SizedBox(height: 12),
              TextFormField(controller: _npm, decoration: const InputDecoration(labelText: 'NPM', prefixIcon: Icon(Icons.numbers_rounded)), validator: (v) {
                if (_req(v, 'NPM') != null) return 'NPM wajib diisi';
                return RegExp(r'^[0-9A-Za-z]{6,20}$').hasMatch(v!.trim()) ? null : 'NPM tidak valid';
              }),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Format email tidak valid',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Nomor HP', prefixIcon: Icon(Icons.phone_android_rounded)),
                validator: (v) => RegExp(r'^[0-9+\-\s]{8,16}$').hasMatch((v ?? '').trim()) ? null : 'Nomor HP tidak valid',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pw,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _obscure = !_obscure)),
                ),
                validator: (v) => (v ?? '').length >= 6 ? null : 'Password minimal 6 karakter',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pw2,
                obscureText: _obscure,
                decoration: const InputDecoration(labelText: 'Ulangi password', prefixIcon: Icon(Icons.lock_reset_rounded)),
                validator: (v) => v == _pw.text ? null : 'Password tidak sama',
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: !isDriver
                    ? const SizedBox(width: double.infinity)
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const SectionTitle('Data kendaraan'),
                        TextFormField(controller: _vehicle, decoration: const InputDecoration(labelText: 'Merek & tipe motor', hintText: 'Honda Beat', prefixIcon: Icon(Icons.two_wheeler_rounded)), validator: (v) => _req(v, 'Tipe motor')),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(flex: 3, child: TextFormField(controller: _plate, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Plat nomor', hintText: 'BE 1234 AB'), validator: (v) => _req(v, 'Plat'))),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: TextFormField(controller: _color, decoration: const InputDecoration(labelText: 'Warna'))),
                        ]),
                        const SectionTitle('Dokumen verifikasi'),
                        _uploadTile('Foto KTM', 'KTM aktif, tulisan terbaca jelas', _ktm, () => _pick(true)),
                        const SizedBox(height: 12),
                        _uploadTile('Surat pernyataan bermeterai', 'Foto/scan surat bermeterai', _surat, () => _pick(false)),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
                            SizedBox(width: 10),
                            Expanded(child: Text('Dokumen akan diperiksa admin. Anda baru dapat online setelah akun disetujui.', style: TextStyle(fontSize: 12.5, height: 1.4))),
                          ]),
                        ),
                      ]),
              ),
              const SizedBox(height: 24),
              LoadingButton(label: isDriver ? 'Kirim Pendaftaran' : 'Daftar', onPressed: _submit),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _roleCard(String value, IconData icon, String title, String sub) {
    final sel = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: sel ? AppColors.primary : AppColors.greyLight, width: sel ? 2 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: sel ? AppColors.primary : AppColors.grey, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: sel ? AppColors.primaryDark : AppColors.text)),
              Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.grey)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _uploadTile(String title, String hint, XFile? file, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: file == null ? AppColors.greyLight : AppColors.primary, width: file == null ? 1 : 1.6),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: file == null
                ? Container(width: 64, height: 64, color: AppColors.primaryLight, child: const Icon(Icons.upload_file_rounded, color: AppColors.primary, size: 30))
                : Image.file(File(file.path), width: 64, height: 64, fit: BoxFit.cover),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(file == null ? hint : 'Dokumen terpilih — ketuk untuk mengganti', style: TextStyle(fontSize: 12.5, color: file == null ? AppColors.grey : AppColors.success)),
            ]),
          ),
          Icon(file == null ? Icons.add_circle_outline : Icons.check_circle, color: file == null ? AppColors.grey : AppColors.success),
        ]),
      ),
    );
  }
}

