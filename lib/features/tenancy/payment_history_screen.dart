import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/payment_schedule.dart';
import 'tenancy_repository.dart';

final _historyProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
      (ref, tenancyId) =>
          ref.watch(tenancyRepositoryProvider).paymentHistory(tenancyId),
    );

/// "Lihat riwayat" (DESIGN §25): seluruh due date + status efektif.
class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key, required this.tenancyId});

  final String tenancyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(_historyProvider(tenancyId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat pembayaran')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Gagal memuat riwayat.'),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(_historyProvider(tenancyId)),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Belum ada jadwal pembayaran.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }
          final now = DateTime.now();
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = list[i];
              final due = parseDateOnly(r['due_date']);
              final status = effectivePaymentStatus('${r['status']}', due, now);
              final (icon, color) = switch (status) {
                'paid' => (Icons.check_circle_outline, scheme.primary),
                'overdue' => (Icons.warning_amber_outlined, scheme.error),
                _ => (Icons.schedule, scheme.tertiary),
              };
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon, color: color),
                title: Text(
                  '${due.day.toString().padLeft(2, '0')}/'
                  '${due.month.toString().padLeft(2, '0')}/${due.year}'
                  ' · Rp${r['amount']}',
                ),
                subtitle: Text(paymentStatusLabel(status)),
                trailing: r['paid_at'] != null
                    ? Text(
                        'dibayar ${_fmt(r['paid_at'])}',
                        style: Theme.of(context).textTheme.labelSmall,
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  String _fmt(Object? v) {
    final d = DateTime.tryParse('$v');
    if (d == null) return '—';
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}
