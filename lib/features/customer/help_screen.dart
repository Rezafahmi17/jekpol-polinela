import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../widgets/common.dart';

/// Tab Bantuan: panduan, pengaduan, informasi layanan. Dipakai customer & driver.
class HelpScreen extends StatefulWidget {
  final bool isDriver;
  const HelpScreen({super.key, this.isDriver = false});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _key = GlobalKey<AsyncPageState>();

  List<(String, String)> get _guide => widget.isDriver
      ? const [
          ('Menjadi driver', 'Daftar dengan mengunggah foto KTM dan surat pernyataan bermeterai. Admin akan memverifikasi dokumen Anda sebelum Anda dapat online.'),
          ('Menerima pesanan', 'Aktifkan tombol Online. Pesanan masuk akan muncul otomatis. Driver yang pertama menekan Terima mendapatkan pesanan.'),
          ('Mengantar penumpang', 'Tekan Mulai Navigasi untuk menuju lokasi jemput, konfirmasi Sudah Dijemput, lalu navigasi ke tujuan dan Selesaikan perjalanan.'),
          ('Pembayaran tunai', 'Setelah perjalanan selesai, terima uang tunai dari customer lalu konfirmasi pembayaran diterima di aplikasi.'),
          ('Pembatalan & penalti', 'Pembatalan setelah menerima pesanan wajib disertai alasan. Pembatalan tanpa alasan yang dapat diterima akan menambah poin pelanggaran, dan akun dapat diblokir otomatis.'),
        ]
      : const [
          ('Cara memesan ojek', 'Pilih tujuan di Beranda, cek estimasi tarif, lalu tekan Pesan Ojek. Sistem akan mencarikan driver online terdekat.'),
          ('Pembayaran', 'Pembayaran dilakukan secara tunai (cash) langsung kepada driver setelah perjalanan selesai.'),
          ('Membatalkan pesanan', 'Anda dapat membatalkan pesanan selama belum diterima driver. Setelah diterima driver, pesanan tidak dapat dibatalkan dari aplikasi.'),
          ('Memantau driver', 'Posisi driver, rute, dan estimasi tiba tampil real-time di peta Beranda selama pesanan berlangsung.'),
          ('Rating & ulasan', 'Setelah perjalanan selesai, beri 1–5 bintang dan ulasan untuk driver. Satu pesanan hanya dapat dinilai satu kali.'),
        ];

  Future<void> _newComplaint() async {
    final subject = TextEditingController();
    final message = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool busy = false;
        return StatefulBuilder(builder: (ctx, setS) {
          return AlertDialog(
            title: const Text('Buat Pengaduan', style: TextStyle(fontWeight: FontWeight.w800)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: subject, decoration: const InputDecoration(labelText: 'Judul pengaduan')),
                const SizedBox(height: 12),
                TextField(controller: message, maxLines: 4, decoration: const InputDecoration(labelText: 'Jelaskan masalah Anda', alignLabelWithHint: true)),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: AppColors.grey))),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
                onPressed: busy
                    ? null
                    : () async {
                        setS(() => busy = true);
                        try {
                          await Api.post('complaints', body: {'subject': subject.text.trim(), 'message': message.text.trim()});
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          setS(() => busy = false);
                          if (ctx.mounted) showError(ctx, e);
                        }
                      },
                child: const Text('Kirim'),
              ),
            ],
          );
        });
      },
    );
    if (sent == true) {
      if (mounted) showMsg(context, 'Pengaduan terkirim. Admin akan menindaklanjuti.');
      _key.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bantuan')),
      body: AsyncPage(
        key: _key,
        load: () async {
          final c = await Api.get('complaints');
          final cfg = await Api.get('config');
          return {...c, 'config': cfg};
        },
        builder: (context, data) {
          final complaints = (data['complaints'] as List).cast<Map>();
          final t = data['config']['tariff'] as Map;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              const SectionTitle('Panduan penggunaan'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (var i = 0; i < _guide.length; i++) ...[
                    ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: const Icon(Icons.help_outline_rounded, color: AppColors.primary),
                      title: Text(_guide[i].$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      expandedAlignment: Alignment.centerLeft,
                      children: [Text(_guide[i].$2, style: const TextStyle(color: AppColors.grey, height: 1.45))],
                    ),
                    if (i < _guide.length - 1) const Divider(),
                  ],
                ]),
              ),
              const SectionTitle('Informasi layanan'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(children: [
                    InfoRow(Icons.attach_money_rounded, 'Tarif dasar', Fmt.rupiah((t['base_fare'] as num))),
                    InfoRow(Icons.speed_rounded, 'Tarif per km', Fmt.rupiah((t['per_km_rate'] as num))),
                    const InfoRow(Icons.payments_rounded, 'Pembayaran', 'Tunai (Cash)'),
                    const InfoRow(Icons.school_rounded, 'Area layanan', 'Lingkungan Polinela'),
                  ]),
                ),
              ),
              SectionTitle('Pengaduan', trailing: TextButton.icon(onPressed: _newComplaint, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Buat'))),
              if (complaints.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Belum ada pengaduan', style: TextStyle(color: AppColors.grey)))))
              else
                for (final c in complaints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text('${c['subject']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                            StatusChip(c['status'] == 'resolved' ? 'Ditanggapi' : 'Diproses', c['status'] == 'resolved' ? AppColors.success : AppColors.warning),
                          ]),
                          const SizedBox(height: 4),
                          Text('${c['message']}', style: const TextStyle(color: AppColors.grey, height: 1.4)),
                          if (c['response'] != null) ...[
                            const Divider(height: 18),
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.support_agent_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(child: Text('${c['response']}', style: const TextStyle(height: 1.4))),
                            ]),
                          ],
                          const SizedBox(height: 6),
                          Text(Fmt.dateTime(c['created_at']), style: const TextStyle(color: AppColors.grey, fontSize: 11.5)),
                        ]),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
