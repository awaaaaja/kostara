import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'tenancy_repository.dart';

final _upcomingDuesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
      (ref, tenancyId) =>
          ref.watch(tenancyRepositoryProvider).upcomingDues(tenancyId),
    );

class TenancyScreen extends ConsumerWidget {
  const TenancyScreen({super.key});

  String _fmtDate(Object? v) {
    if (v == null) return '—';
    final d = DateTime.tryParse('$v');
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myTenancyRequestsProvider);
    final tenancies = ref.watch(myTenanciesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sewa kamu')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myTenancyRequestsProvider);
          ref.invalidate(myTenanciesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            tenancies.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => const Text('Gagal memuat tenancy.'),
              data: (list) {
                final active = list
                    .where((t) => t['status'] == 'active')
                    .toList();
                final past = list
                    .where((t) => t['status'] != 'active')
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final t in active)
                      _ActiveCard(tenancy: t, fmt: _fmtDate),
                    if (active.isEmpty)
                      Card(
                        elevation: 0,
                        color: scheme.surfaceContainerLow,
                        child: ListTile(
                          leading: const Icon(Icons.home_outlined),
                          title: const Text('Belum ada kos dihuni'),
                          subtitle: const Text(
                            'Ajukan sewa dari halaman detail kos.',
                          ),
                          trailing: TextButton(
                            onPressed: () => context.go('/explore'),
                            child: const Text('Cari kos'),
                          ),
                        ),
                      ),
                    if (past.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Riwayat',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final t in past)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history),
                          title: Text('${t['property']?['name']}'),
                          subtitle: Text(
                            '${t['room']?['code']} · '
                            '${_fmtDate(t['start_date'])}'
                            '${t['end_date'] != null ? ' – ${_fmtDate(t['end_date'])}' : ''}',
                          ),
                          trailing: Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('${t['status']}'),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Permintaan sewa',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            requests.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => const Text('Gagal memuat permintaan.'),
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                    'Belum ada permintaan.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                return Column(
                  children: [
                    for (final r in list)
                      Card(
                        elevation: 0,
                        color: scheme.surfaceContainerLow,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${r['property']?['name']} · '
                                      '${r['room']?['code']}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                  ),
                                  _StatusChip(status: '${r['status']}'),
                                ],
                              ),
                              if (r['message'] != null &&
                                  '${r['message']}'.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '${r['message']}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              if (r['reject_reason'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Alasan ditolak: ${r['reject_reason']}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: scheme.error),
                                  ),
                                ),
                              Row(
                                children: [
                                  Text(
                                    _fmtDate(r['created_at']),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                  const Spacer(),
                                  if (r['status'] == 'pending')
                                    TextButton(
                                      onPressed: () async {
                                        try {
                                          await ref
                                              .read(tenancyRepositoryProvider)
                                              .cancelRequest(r['id'] as String);
                                          ref.invalidate(
                                            myTenancyRequestsProvider,
                                          );
                                        } catch (_) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Gagal membatalkan. Coba lagi.',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: const Text('Batalkan'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveCard extends ConsumerWidget {
  const _ActiveCard({required this.tenancy, required this.fmt});

  final Map<String, dynamic> tenancy;
  final String Function(Object?) fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final id = tenancy['id'] as String;
    final dues = ref.watch(_upcomingDuesProvider(id));
    final schedule = (tenancy['payment_schedules'] as List?)
        ?.cast<Map<String, dynamic>>();
    final nextDue = schedule == null || schedule.isEmpty
        ? null
        : schedule.first['next_due_date'];

    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.home, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${tenancy['property']?['name']}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: scheme.primary,
                  labelStyle: TextStyle(color: scheme.onPrimary),
                  label: const Text('Aktif'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Kamar ${tenancy['room']?['code']} · mulai '
              '${fmt(tenancy['start_date'])} · '
              'Rp${tenancy['amount']} / bulan',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              nextDue == null
                  ? 'Jadwal pembayaran menyusul'
                  : 'Tagihan berikutnya ${fmt(nextDue)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            dues.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => const SizedBox.shrink(),
              data: (list) => Column(
                children: [
                  for (final d in list)
                    Row(
                      children: [
                        Icon(
                          d['status'] == 'paid'
                              ? Icons.check_circle_outline
                              : Icons.schedule,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${fmt(d['due_date'])} · Rp${d['amount']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          '${d['status']}' == 'paid' ? 'Lunas' : 'Belum',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      'pending' => ('Menunggu keputusan', scheme.tertiary),
      'accepted' => ('Diterima', scheme.primary),
      'rejected' => ('Ditolak', scheme.error),
      _ => ('Dibatalkan', scheme.outline),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}
