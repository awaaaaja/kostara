import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_repository.dart';
import 'admin_repository.dart';

/// Ringkasan platform + antrian moderasi + model (FR-ADM-01, AC-ADM-07).
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(adminOverviewProvider);
    final models = ref.watch(adminModelVersionsProvider);
    final counts = ref.watch(adminInteractionCountsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminOverviewProvider);
          ref.invalidate(adminModelVersionsProvider);
          ref.invalidate(adminInteractionCountsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            overview.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Column(
                children: [
                  const Text('Gagal memuat ringkasan.'),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => ref.invalidate(adminOverviewProvider),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
              data: (o) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _Stat('Pengguna', o.users),
                      _Stat('Kos', o.properties),
                      _Stat('Kamar', o.rooms),
                      _Stat('Sewa', o.tenancies),
                      _Stat('Ulasan', o.reviews),
                      _Stat('Laporan', o.reports),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Antrian moderasi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  _QueueTile(
                    icon: Icons.verified_user_outlined,
                    label: 'Verifikasi owner',
                    count: o.ownerPending,
                    onTap: () => context.go('/admin/verify'),
                  ),
                  _QueueTile(
                    icon: Icons.home_outlined,
                    label: 'Review listing',
                    count: o.listingPending,
                    onTap: () => context.go('/admin/verify'),
                  ),
                  _QueueTile(
                    icon: Icons.flag_outlined,
                    label: 'Laporan terbuka',
                    count: o.reportsOpen,
                    onTap: () => context.go('/admin/moderation'),
                  ),
                  _QueueTile(
                    icon: Icons.rate_review_outlined,
                    label: 'Ulasan menunggu',
                    count: o.reviewsPending,
                    onTap: () => context.go('/admin/moderation'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Ringkasan model',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            models.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => const Text('Gagal memuat model.'),
              data: (list) {
                if (list.isEmpty) {
                  return const Text(
                    'Belum ada model terdaftar.',
                    style: TextStyle(fontSize: 13),
                  );
                }
                return Column(
                  children: [
                    for (final m in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(
                          m['status'] == 'active'
                              ? Icons.check_circle_outline
                              : Icons.circle_outlined,
                          color: m['status'] == 'active'
                              ? scheme.primary
                              : scheme.outline,
                        ),
                        title: Text('${m['name']} (${m['kind']})'),
                        subtitle: Text(
                          '${m['status']} · dataset ${m['dataset_version']}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Interaksi per event',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            counts.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => const Text('Gagal memuat interaksi.'),
              data: (m) {
                if (m.isEmpty) {
                  return const Text(
                    'Belum ada event tercatat.',
                    style: TextStyle(fontSize: 13),
                  );
                }
                final sorted = m.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in sorted)
                      Text(
                        '${e.key}: ${e.value}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0)
            CircleAvatar(
              radius: 12,
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              child: Text('$count', style: const TextStyle(fontSize: 11)),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}
