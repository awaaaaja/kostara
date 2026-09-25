import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'owner_repository.dart';

class OwnerTenantsScreen extends ConsumerStatefulWidget {
  const OwnerTenantsScreen({super.key});

  @override
  ConsumerState<OwnerTenantsScreen> createState() => _OwnerTenantsScreenState();
}

class _OwnerTenantsScreenState extends ConsumerState<OwnerTenantsScreen> {
  Future<void> _accept(Map<String, dynamic> r) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Terima permintaan?'),
        content: Text(
          'Kamar ${r['room']?['code']} (${r['property']?['name']}) akan '
          'langsung ditempati dan jadwal pembayaran dibuat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Terima'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(ownerRepositoryProvider).acceptRequest(r['id'] as String);
      ref.invalidate(ownerPendingRequestsProvider);
      ref.invalidate(ownerActiveTenantsProvider);
      ref.invalidate(ownerDashboardProvider);
      ref.invalidate(ownerDuePaymentsProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Permintaan diterima.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_friendlyAcceptError(e))));
    }
  }

  String _friendlyAcceptError(Object e) {
    final raw = e.toString();
    if (raw.contains('room_sudah_terisi')) return 'Kamar sudah terisi.';
    if (raw.contains('status_tidak_valid')) {
      return 'Permintaan sudah diputuskan sebelumnya.';
    }
    if (raw.contains('bukan_pemilik')) return 'Bukan properti milikmu.';
    return 'Gagal menerima permintaan. Coba lagi.';
  }

  Future<void> _reject(Map<String, dynamic> r) async {
    final reason = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tolak permintaan'),
        content: TextField(
          controller: reason,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Alasan (wajib)',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (reason.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Alasan wajib diisi.')),
      );
      return;
    }
    try {
      await ref
          .read(ownerRepositoryProvider)
          .rejectRequest(r['id'] as String, reason.text);
      ref.invalidate(ownerPendingRequestsProvider);
      ref.invalidate(ownerDashboardProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Permintaan ditolak.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal menolak. Coba lagi.')),
      );
    } finally {
      reason.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(ownerPendingRequestsProvider);
    final tenants = ref.watch(ownerActiveTenantsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Penyewa')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ownerPendingRequestsProvider);
          ref.invalidate(ownerActiveTenantsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Permintaan pending',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            pending.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => const Text('Gagal memuat permintaan.'),
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                    'Tidak ada permintaan baru.',
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
                              Text(
                                '${r['property']?['name']} · ${r['room']?['code']}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                'Pengaju: ${r['seeker']?['full_name'] ?? '—'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (r['message'] != null &&
                                  '${r['message']}'.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '"${r['message']}"',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => _reject(r),
                                    child: const Text('Tolak'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.tonal(
                                    onPressed: () => _accept(r),
                                    child: const Text('Terima'),
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
            const SizedBox(height: 20),
            Text(
              'Penyewa aktif',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            tenants.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => const Text('Gagal memuat penyewa.'),
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                    'Belum ada penyewa aktif.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                }
                return Column(
                  children: [
                    for (final t in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: Text(
                          '${t['seeker']?['full_name'] ?? 'Penyewa'} · '
                          '${t['room']?['code']}',
                        ),
                        subtitle: Text(
                          '${t['property']?['name']} · mulai '
                          '${'${t['start_date']}'.substring(0, 10)}',
                        ),
                        trailing: Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('Rp${t['amount']}'),
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
