import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'owner_repository.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(ownerDashboardProvider);
    final pending = ref.watch(ownerPendingRequestsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ringkasan')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ownerDashboardProvider);
          ref.invalidate(ownerPendingRequestsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            dash.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Column(
                children: [
                  const Text('Gagal memuat ringkasan.'),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => ref.invalidate(ownerDashboardProvider),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
              data: (d) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _Metric(
                    label: 'Kos aktif',
                    value: '${d['properties_active']}',
                    sub: '${d['properties_total']} total',
                    icon: Icons.home_work_outlined,
                    color: scheme.primary,
                  ),
                  _Metric(
                    label: 'Permintaan pending',
                    value: '${d['requests_pending']}',
                    sub: 'menunggu keputusan',
                    icon: Icons.mark_email_unread_outlined,
                    color: scheme.tertiary,
                  ),
                  _Metric(
                    label: 'Tagihan belum lunas',
                    value: '${d['payments_unpaid']}',
                    sub: 'periksa pembayaran',
                    icon: Icons.receipt_long_outlined,
                    color: scheme.error,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Permintaan masuk',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/owner/tenants'),
                  child: const Text('Semua'),
                ),
              ],
            ),
            pending.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => const Text('Gagal memuat permintaan.'),
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                    'Belum ada permintaan baru.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                return Column(
                  children: [
                    for (final r in list.take(3))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text(
                          '${r['property']?['name']} · ${r['room']?['code']}',
                        ),
                        subtitle: Text(
                          'Pengaju: ${r['seeker']?['full_name'] ?? '—'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/owner/tenants'),
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

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(sub, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
