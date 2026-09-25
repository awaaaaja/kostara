import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/util/payment_schedule.dart';
import 'owner_repository.dart';

class OwnerPaymentsScreen extends ConsumerWidget {
  const OwnerPaymentsScreen({super.key});

  String _fmtDate(Object? v) {
    final d = DateTime.tryParse('$v');
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _markPaid(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tandai lunas?'),
        content: Text(
          'Rp${row['amount']} untuk ${_fmtDate(row['due_date'])} '
          '(penyewa ${row['tenancy']?['seeker']?['full_name'] ?? '—'}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Tandai lunas'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(ownerRepositoryProvider).markPaid(row['id'] as String);
      ref.invalidate(ownerDuePaymentsProvider);
      ref.invalidate(ownerDashboardProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Pembayaran ditandai lunas.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal memperbarui. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(ownerDuePaymentsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: payments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Gagal memuat pembayaran.'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(ownerDuePaymentsProvider),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
        data: (list) {
          final due = list.where((r) => r['status'] != 'paid').toList();
          final paid = list.where((r) => r['status'] == 'paid').toList();
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: scheme.outline,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada tagihan.\nJadwal dibuat saat permintaan diterima.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ownerDuePaymentsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (due.isNotEmpty) ...[
                  Text(
                    'Belum lunas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final r in due)
                    Builder(
                      builder: (context) {
                        // Status efektif dihitung helper bersama (AC-PAY-06);
                        // DB hanya menyimpan unpaid — overdue diturunkan.
                        final status = effectivePaymentStatus(
                          '${r['status']}',
                          parseDateOnly(r['due_date']),
                          DateTime.now(),
                        );
                        final overdue = status == 'overdue';
                        return Card(
                          elevation: 0,
                          color: scheme.surfaceContainerLow,
                          child: ListTile(
                            leading: Icon(
                              overdue
                                  ? Icons.warning_amber_outlined
                                  : Icons.schedule,
                              color: overdue ? scheme.error : scheme.tertiary,
                            ),
                            title: Text(
                              '${r['tenancy']?['property']?['name']} · '
                              '${r['tenancy']?['room']?['code']}',
                            ),
                            subtitle: Text(
                              '${_fmtDate(r['due_date'])} · Rp${r['amount']} · '
                              '${paymentStatusLabel(status)} · '
                              '${r['tenancy']?['seeker']?['full_name'] ?? '—'}',
                            ),
                            trailing: FilledButton.tonal(
                              onPressed: () => _markPaid(context, ref, r),
                              child: const Text('Lunas'),
                            ),
                          ),
                        );
                      },
                    ),
                ],
                if (paid.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Lunas', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final r in paid)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.check_circle_outline,
                        color: scheme.primary,
                      ),
                      title: Text(
                        '${r['tenancy']?['property']?['name']} · '
                        '${r['tenancy']?['room']?['code']}',
                      ),
                      subtitle: Text(
                        '${_fmtDate(r['due_date'])} · Rp${r['amount']} · '
                        'dibayar ${_fmtDate(r['paid_at'])}',
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
