import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import '../../widgets/order_widgets.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan & Layanan'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Semua Pesanan'),
            Tab(text: 'Pembatalan'),
            Tab(text: 'Review Penalti'),
            Tab(text: 'Pengaduan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _AllOrdersTab(),
          _CancellationsTab(),
          _PenaltiesTab(),
          _ComplaintsTab(),
        ],
      ),
    );
  }
}

class _AllOrdersTab extends StatelessWidget {
  const _AllOrdersTab();

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      load: () => Api.get('admin/orders'),
      builder: (context, data) {
        final list = (data['orders'] as List).map((e) => Order.fromJson(e)).toList();
        if (list.isEmpty) {
          return const EmptyScroll(
            icon: Icons.electric_moped_rounded,
            title: 'Belum ada pesanan',
          );
        }
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => OrderTile(order: list[i], perspective: 'admin'),
        );
      },
    );
  }
}

class _CancellationsTab extends StatelessWidget {
  const _CancellationsTab();

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      load: () => Api.get('admin/cancellations'),
      builder: (context, data) {
        final list = (data['orders'] as List).map((e) => Order.fromJson(e)).toList();
        if (list.isEmpty) {
          return const EmptyScroll(
            icon: Icons.check_circle_outline_rounded,
            title: 'Tidak ada pembatalan',
            subtitle: 'Semua pesanan berjalan lancar.',
          );
        }
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final o = list[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(o.code, style: const TextStyle(fontWeight: FontWeight.w800))),
                    StatusChip(o.statusLabel, AppColors.danger),
                  ]),
                  const SizedBox(height: 4),
                  Text('Alasan: ${o.cancelReason ?? "Tidak ada keterangan"}',
                      style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  RouteSummary(pickup: o.pickupAddress, dest: o.destAddress),
                  const Divider(height: 16),
                  Text(
                    'Customer: ${o.customerName} • Driver: ${o.driver?.name ?? "-"} • ${Fmt.dateTime(o.createdAt)}',
                    style: const TextStyle(color: AppColors.grey, fontSize: 12),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

class _PenaltiesTab extends StatefulWidget {
  const _PenaltiesTab();

  @override
  State<_PenaltiesTab> createState() => _PenaltiesTabState();
}

class _PenaltiesTabState extends State<_PenaltiesTab> {
  final _key = GlobalKey<AsyncPageState>();

  Future<void> _review(int id, String decision) async {
    try {
      await Api.post('admin/penalties/$id/review', body: {'decision': decision});
      if (mounted) showMsg(context, decision == 'violation' ? 'Ditetapkan sebagai pelanggaran' : 'Pembatalan diterima (bebas penalti)');
      _key.currentState?.reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      key: _key,
      load: () => Api.get('admin/penalties'),
      builder: (context, data) {
        final list = (data['penalties'] as List).cast<Map>();
        if (list.isEmpty) {
          return const EmptyScroll(
            icon: Icons.shield_outlined,
            title: 'Tidak ada data penalti',
          );
        }
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final p = list[i];
            final pending = p['status'] == 'pending_review';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text('Driver: ${p['driver_name']}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                    StatusChip(
                      pending ? 'Perlu Ditinjau' : (p['status'] == 'violation' ? 'Pelanggaran' : 'Bebas Penalti'),
                      pending ? AppColors.warning : (p['status'] == 'violation' ? AppColors.danger : AppColors.success),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text('Kategori: ${p['reason_category']} • Alasan: "${p['reason_text']}"',
                      style: const TextStyle(fontSize: 13, height: 1.3)),
                  const SizedBox(height: 4),
                  Text('Tanggal: ${Fmt.dateTime(p['created_at'])} • Poin: +${p['points']}',
                      style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                  if (pending) ...[
                    const Divider(height: 20),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _review(p['id'], 'dismissed'),
                          child: const Text('Bebaskan (Alasan Sah)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                          onPressed: () => _review(p['id'], 'violation'),
                          child: const Text('Beri Penalti (+1)'),
                        ),
                      ),
                    ]),
                  ],
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

class _ComplaintsTab extends StatefulWidget {
  const _ComplaintsTab();

  @override
  State<_ComplaintsTab> createState() => _ComplaintsTabState();
}

class _ComplaintsTabState extends State<_ComplaintsTab> {
  final _key = GlobalKey<AsyncPageState>();

  Future<void> _reply(int id) async {
    final resp = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tanggapi Pengaduan', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: resp,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Jawaban / Solusi untuk pengguna', alignLabelWithHint: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kirim Tanggapan')),
        ],
      ),
    );
    if (ok == true && resp.text.trim().isNotEmpty) {
      try {
        await Api.post('admin/complaints/$id/resolve', body: {'response': resp.text.trim()});
        if (mounted) showMsg(context, 'Pengaduan berhasil ditanggapi');
        _key.currentState?.reload();
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      key: _key,
      load: () => Api.get('admin/complaints'),
      builder: (context, data) {
        final list = (data['complaints'] as List).cast<Map>();
        if (list.isEmpty) {
          return const EmptyScroll(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Tidak ada pengaduan',
          );
        }
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final c = list[i];
            final isOpen = c['status'] == 'open';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text('${c['subject']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                    StatusChip(isOpen ? 'Menunggu Tanggapan' : 'Selesai', isOpen ? AppColors.warning : AppColors.success),
                  ]),
                  const SizedBox(height: 4),
                  Text('Dari: ${c['user_name']} (${c['user_role']}) • ${Fmt.dateTime(c['created_at'])}',
                      style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('${c['message']}', style: const TextStyle(fontSize: 13, height: 1.35)),
                  if (c['response'] != null) ...[
                    const Divider(height: 16),
                    Text('Tanggapan Admin: ${c['response']}',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                  if (isOpen) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size(120, 38)),
                        onPressed: () => _reply(c['id']),
                        icon: const Icon(Icons.reply_rounded, size: 18),
                        label: const Text('Tanggapi'),
                      ),
                    ),
                  ],
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

