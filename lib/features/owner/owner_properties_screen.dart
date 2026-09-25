import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'owner_repository.dart';

class OwnerPropertiesScreen extends ConsumerWidget {
  const OwnerPropertiesScreen({super.key});

  Future<void> _toggleArchive(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> p,
  ) async {
    final id = p['id'] as String;
    final activate = p['listing_status'] != 'active';
    if (activate && p['verification_status'] != 'verified') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kos harus terverifikasi sebelum ditayangkan.'),
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(ownerRepositoryProvider)
          .updateProperty(
            id,
            fields: {'listing_status': activate ? 'active' : 'archived'},
          );
      ref.invalidate(ownerPropertiesProvider);
      ref.invalidate(ownerDashboardProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(activate ? 'Kos ditayangkan.' : 'Kos diarsipkan.'),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal mengubah status. Coba lagi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(ownerPropertiesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Properti saya')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/owner/add'),
        icon: const Icon(Icons.add),
        label: const Text('Tambah kos'),
      ),
      body: properties.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text('Gagal memuat properti.'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(ownerPropertiesProvider),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.home_work_outlined,
                      size: 48,
                      color: scheme.outline,
                    ),
                    const SizedBox(height: 12),
                    const Text('Belum ada kos. Tambahkan properti pertama.'),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => context.push('/owner/add'),
                      child: const Text('Tambah kos'),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ownerPropertiesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = list[i];
                final rooms = (p['rooms'] as List?) ?? const [];
                final free = rooms
                    .where((r) => r['status'] == 'available')
                    .length;
                final active = p['listing_status'] == 'active';
                final verified = p['verification_status'] == 'verified';
                return Card(
                  elevation: 0,
                  color: scheme.surfaceContainerLow,
                  child: ListTile(
                    title: Text('${p['name']}'),
                    subtitle: Text(
                      '$free/${rooms.length} kamar be · ${verified ? 'terverifikasi' : 'belum terverifikasi'}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'manage') {
                          context.push('/owner/properties/${p['id']}');
                        } else if (v == 'toggle') {
                          _toggleArchive(context, ref, p);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'manage',
                          child: Text('Kelola detail & kamar'),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(active ? 'Arsipkan' : 'Tayangkan'),
                        ),
                      ],
                    ),
                    leading: Icon(
                      active ? Icons.home : Icons.inventory_2_outlined,
                      color: active ? scheme.primary : scheme.outline,
                    ),
                    onTap: () => context.push('/owner/properties/${p['id']}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
