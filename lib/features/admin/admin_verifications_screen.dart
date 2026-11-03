import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class AdminVerificationsScreen extends StatefulWidget {
  const AdminVerificationsScreen({super.key});

  @override
  State<AdminVerificationsScreen> createState() => _AdminVerificationsScreenState();
}

class _AdminVerificationsScreenState extends State<AdminVerificationsScreen> {
  final _key = GlobalKey<AsyncPageState>();
  String _status = 'pending';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifikasi Driver'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                for (final s in const [
                  ('pending', 'Menunggu'),
                  ('approved', 'Disetujui'),
                  ('rejected', 'Ditolak'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s.$2),
                      selected: _status == s.$1,
                      selectedColor: AppColors.primaryLight,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _status == s.$1 ? AppColors.primaryDark : AppColors.grey,
                      ),
                      onSelected: (_) {
                        setState(() => _status = s.$1);
                        _key.currentState?.reload();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncPage(
              key: _key,
              load: () => Api.get('admin/verifications', query: {'status': _status}),
              builder: (context, data) {
                final drivers = (data['drivers'] as List).map((e) => AppUser.fromJson(e)).toList();

                if (drivers.isEmpty) {
                  return EmptyScroll(
                    icon: Icons.assignment_turned_in_rounded,
                    title: 'Tidak ada driver',
                    subtitle: 'Driver dengan status "$_status" tidak ditemukan.',
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: drivers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final d = drivers[i];
                    final di = d.driver;
                    return Card(
                      child: ListTile(
                        leading: Avatar(d.initials, size: 44),
                        title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          'NPM: ${d.npm ?? "-"}\nMotor: ${di?.vehicle ?? "-"} (${di?.plate ?? "-"})',
                          style: const TextStyle(height: 1.3),
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right, color: AppColors.grey),
                        onTap: () => _openDetail(d),
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

  Future<void> _openDetail(AppUser d) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => _DriverVerificationDetailSheet(driverId: d.id, scroll: scroll),
      ),
    );
    if (changed == true) {
      _key.currentState?.reload();
    }
  }
}

class _DriverVerificationDetailSheet extends StatefulWidget {
  final int driverId;
  final ScrollController scroll;
  const _DriverVerificationDetailSheet({required this.driverId, required this.scroll});

  @override
  State<_DriverVerificationDetailSheet> createState() => _DriverVerificationDetailSheetState();
}

class _DriverVerificationDetailSheetState extends State<_DriverVerificationDetailSheet> {
  late final Future<Map<String, dynamic>> _f = Api.get('admin/users/${widget.driverId}');
  bool _busy = false;

  Future<void> _verify(String decision, [String? reason]) async {
    setState(() => _busy = true);
    try {
      await Api.post('admin/drivers/${widget.driverId}/verify', body: {
        'decision': decision,
        if (reason != null) 'reason': reason,
      });
      if (!mounted) return;
      showMsg(context, decision == 'approve' ? 'Driver berhasil disetujui!' : 'Driver ditolak.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showRejectDialog() {
    final reason = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak Pendaftaran Driver', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Masukkan alasan penolakan dokumen (akan dikirimkan ke calon driver):',
              style: TextStyle(fontSize: 13, color: AppColors.grey)),
          const SizedBox(height: 12),
          TextField(
            controller: reason,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Alasan penolakan', alignLabelWithHint: true),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              if (reason.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              _verify('reject', reason.text.trim());
            },
            child: const Text('Tolak Driver'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData || snap.data!['user'] == null) {
          return EmptyState(icon: Icons.error_outline, title: 'Gagal memuat', subtitle: '${snap.error ?? "Data tidak ditemukan"}');
        }

        final u = AppUser.fromJson(snap.data!['user']);
        final di = u.driver;
        final docs = (snap.data!['user']['documents'] as List? ?? []).cast<Map>();

        return ListView(
          controller: widget.scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const SheetHandle(),
            Row(children: [
              Avatar(u.initials, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  Text('NPM: ${u.npm ?? "-"} • ${u.phone}',
                      style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  StatusChip(
                    switch (di?.verificationStatus) {
                      'approved' => 'Disetujui',
                      'rejected' => 'Ditolak',
                      _ => 'Menunggu Verifikasi',
                    },
                    switch (di?.verificationStatus) {
                      'approved' => AppColors.success,
                      'rejected' => AppColors.danger,
                      _ => AppColors.warning,
                    },
                  ),
                ]),
              ),
            ]),
            const Divider(height: 28),
            const SectionTitle('Data Kendaraan'),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(children: [
                  InfoRow(Icons.two_wheeler_rounded, 'Merek & Tipe', di?.vehicle ?? '-'),
                  InfoRow(Icons.pin_rounded, 'Plat Nomor', di?.plate ?? '-'),
                  InfoRow(Icons.color_lens_rounded, 'Warna Kendaraan', di?.vehicleColor ?? '-'),
                ]),
              ),
            ),
            const SectionTitle('Dokumen Pendaftaran'),
            if (docs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Tidak ada dokumen yang diunggah.', style: TextStyle(color: AppColors.grey)),
                ),
              )
            else
              for (final doc in docs) ...[
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    ListTile(
                      leading: Icon(
                        doc['doc_type'] == 'ktm' ? Icons.badge_outlined : Icons.description_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        doc['doc_type'] == 'ktm' ? 'Foto KTM Mahasiswa' : 'Surat Pernyataan Bermeterai',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${doc['original_name'] ?? "Dokumen"}'),
                    ),
                    if (doc['is_image'] == true)
                      Container(
                        height: 220,
                        color: Colors.black12,
                        child: Image.network(
                          Api.authedUrl('admin/documents/${doc['id']}'),
                          headers: Api.authHeaders,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text('Gagal menampilkan pratinjau gambar',
                                style: TextStyle(color: AppColors.grey)),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.picture_as_pdf_rounded),
                            label: const Text('Dokumen PDF'),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  onPressed: _busy ? null : _showRejectDialog,
                  child: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _busy ? null : () => _verify('approve'),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Setujui Driver'),
                ),
              ),
            ]),
          ],
        );
      },
    );
  }
}

