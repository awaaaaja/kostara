import 'package:flutter/material.dart';

/// Ringkasan ToS & privasi v1.0 — wajib bisa dibaca sebelum mencentang
/// persetujuan (cp02-privacy §3). Teks lengkap: docs/tos-v1.0.md.
Future<void> showTosSummarySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ringkasan ToS & Privasi v1.0',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const _Item(
              icon: Icons.assignment_outlined,
              text:
                  'Persetujuan Anda dicatat beserta versi syarat (v1.0) '
                  'dan waktu saat mendaftar.',
            ),
            const _Item(
              icon: Icons.storage_outlined,
              text:
                  'Data akun, preferensi, dan riwayat sewa disimpan selama '
                  'diperlukan; data interaksi (pencarian/simpan) hanya bila '
                  'Anda setuju, bisa ditarik kapan saja, retensi 24 bulan.',
            ),
            const _Item(
              icon: Icons.my_location_outlined,
              text:
                  'Lokasi GPS hanya dipakai sesaat saat tombol "Lokasi '
                  'saya" ditekan dan tidak pernah disimpan.',
            ),
            const _Item(
              icon: Icons.rate_review_outlined,
              text:
                  'Review yang Anda posting berlisensi kepada pengelola '
                  'untuk ditampilkan dan untuk melatih/mengevaluasi model '
                  'analisis review, selama review ditayangkan.',
            ),
            const _Item(
              icon: Icons.delete_outline,
              text:
                  'Anda bisa mengakses, memperbaiki data, menarik '
                  'persetujuan interaksi, dan mengajukan hapus akun lewat '
                  'kontak pengelola di aplikasi.',
            ),
            const _Item(
              icon: Icons.account_balance_wallet_outlined,
              text:
                  'KOSTARA tidak memproses pembayaran online; transfer '
                  'sewa dilakukan langsung antara penghuni dan pemilik.',
            ),
            const _Item(
              icon: Icons.straighten_outlined,
              text:
                  'Jarak yang ditampilkan adalah garis lurus dari '
                  'koordinat — bukan waktu tempuh.',
            ),
            const SizedBox(height: 8),
            Text(
              'Teks lengkap: docs/tos-v1.0.md (repo proyek).',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
