import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';
import '../../widgets/profile_view.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> with SingleTickerProviderStateMixin {
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
        title: const Text('Tarif, Sistem & Akun'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Pengaturan Tarif & Aturan'),
            Tab(text: 'Laporan Keuangan & Statistik'),
            Tab(text: 'Log Aktivitas Super Admin'),
            Tab(text: 'Profil & Sesi Super Admin'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _TariffAndSettingsTab(),
          _ReportsTab(),
          _AdminLogsTab(),
          ProfileView(),
        ],
      ),
    );
  }
}

class _TariffAndSettingsTab extends StatefulWidget {
  const _TariffAndSettingsTab();

  @override
  State<_TariffAndSettingsTab> createState() => _TariffAndSettingsTabState();
}

class _TariffAndSettingsTabState extends State<_TariffAndSettingsTab> {
  final _key = GlobalKey<AsyncPageState>();

  Future<void> _editTariff(int currentBase, int currentKm) async {
    final base = TextEditingController(text: '$currentBase');
    final perKm = TextEditingController(text: '$currentKm');

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Perbarui Tarif Perjalanan', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Pesanan yang sudah dibuat sebelumnya tidak akan terpengaruh.',
              style: TextStyle(fontSize: 12.5, color: AppColors.grey)),
          const SizedBox(height: 14),
          TextField(controller: base, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tarif Dasar (Rp)')),
          const SizedBox(height: 10),
          TextField(controller: perKm, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tarif per Kilometer (Rp)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Simpan Tarif Baru')),
        ],
      ),
    );

    if (ok == true) {
      try {
        await Api.post('admin/tariff', body: {
          'base_fare': int.parse(base.text.trim()),
          'per_km_rate': int.parse(perKm.text.trim()),
        });
        if (mounted) showMsg(context, 'Tarif berhasil diperbarui');
        _key.currentState?.reload();
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
  }

  Future<void> _editSetting(String key, String currentVal, String desc) async {
    final val = TextEditingController(text: currentVal);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ubah Pengaturan Sistem', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.grey)),
          const SizedBox(height: 12),
          TextField(controller: val, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nilai')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok == true && val.text.trim().isNotEmpty) {
      try {
        await Api.post('admin/settings', body: {'key': key, 'value': val.text.trim()});
        if (mounted) showMsg(context, 'Pengaturan sistem disimpan');
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
      load: () => Api.get('admin/settings'),
      builder: (context, data) {
        final t = data['tariff'] as Map;
        final base = (t['base_fare'] as num).toInt();
        final perKm = (t['per_km_rate'] as num).toInt();
        final settings = (data['settings'] as List).cast<Map>();

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            SectionTitle('Tarif Perjalanan',
                trailing: TextButton.icon(
                  onPressed: () => _editTariff(base, perKm),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Ubah Tarif'),
                )),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(children: [
                  InfoRow(Icons.attach_money_rounded, 'Tarif Dasar', Fmt.rupiah(base)),
                  InfoRow(Icons.speed_rounded, 'Tarif per Kilometer', Fmt.rupiah(perKm)),
                  const InfoRow(Icons.functions_rounded, 'Rumus Perhitungan', 'Tarif Dasar + (Jarak × Tarif/km)'),
                ]),
              ),
            ),
            const SectionTitle('Sistem Penalti & Batas Ambang'),
            Card(
              child: Column(children: [
                for (final s in settings)
                  ListTile(
                    title: Text('${s['description'] ?? s['key']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: Text('Parameter: ${s['key']}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${s['value']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary)),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_rounded, size: 18, color: AppColors.grey),
                    ]),
                    onTap: () => _editSetting(s['key'], '${s['value']}', '${s['description'] ?? s['key']}'),
                  ),
              ]),
            ),
          ],
        );
      },
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      load: () => Api.get('admin/reports', query: {'days': 7}),
      builder: (context, data) {
        final totals = data['totals'] as Map;
        final days = (data['days'] as List).cast<Map>();
        final top = (data['top_drivers'] as List).cast<Map>();

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Row(children: [
              Expanded(
                child: StatTile(
                  icon: Icons.payments_rounded,
                  label: 'Omset 7 Hari',
                  value: Fmt.rupiah(totals['revenue'] ?? 0),
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Selesai 7 Hari',
                  value: '${totals['completed'] ?? 0} trip',
                  color: AppColors.primary,
                ),
              ),
            ]),
            const SectionTitle('Tren 7 Hari Terakhir'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  for (final d in days)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        SizedBox(width: 75, child: Text(Fmt.shortDay(d['day']), style: const TextStyle(fontWeight: FontWeight.w700))),
                        Expanded(
                          child: Text(
                            '${d['completed']} selesai • ${d['cancelled']} batal',
                            style: const TextStyle(color: AppColors.grey, fontSize: 12.5),
                          ),
                        ),
                        Text(Fmt.rupiah(d['revenue'] ?? 0), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                    ),
                ]),
              ),
            ),
            if (top.isNotEmpty) ...[
              const SectionTitle('Driver Teraktif (Berdasarkan Trip Selesai)'),
              Card(
                child: Column(children: [
                  for (var i = 0; i < top.length; i++)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: i == 0 ? AppColors.warning : AppColors.primaryLight,
                        child: Text('${i + 1}',
                            style: TextStyle(
                              color: i == 0 ? Colors.white : AppColors.primary,
                              fontWeight: FontWeight.w900,
                            )),
                      ),
                      title: Text('${top[i]['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${top[i]['trips']} trip diselesaikan'),
                      trailing: Text(Fmt.rupiah(top[i]['total'] ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                    ),
                ]),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AdminLogsTab extends StatelessWidget {
  const _AdminLogsTab();

  @override
  Widget build(BuildContext context) {
    return AsyncPage(
      load: () => Api.get('admin/logs'),
      builder: (context, data) {
        final logs = (data['logs'] as List).cast<Map>();
        if (logs.isEmpty) {
          return const EmptyScroll(
            icon: Icons.history_rounded,
            title: 'Belum ada log aktivitas',
          );
        }
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final l = logs[i];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.shield_rounded, color: AppColors.primary),
                title: Text('${l['action']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                subtitle: Text(
                  'Oleh: ${l['admin_name']}\nDetail: ${l['details'] ?? "-"}\nWaktu: ${Fmt.dateTime(l['created_at'])}',
                  style: const TextStyle(fontSize: 12),
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

