import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_dialogs.dart';
import 'admin_repository.dart';

/// Antrian verifikasi owner & listing (FR-ADM-02, DESIGN §32: evidence,
/// approve/reject, alasan wajib untuk reject).
class AdminVerifyScreen extends ConsumerWidget {
  const AdminVerifyScreen({super.key});

  String _fmtDate(Object? v) {
    if (v == null) return '—';
    final d = DateTime.tryParse('$v');
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  void _invalidate(WidgetRef ref) {
    ref.invalidate(adminOverviewProvider);
    ref.invalidate(adminPendingOwnersProvider);
    ref.invalidate(adminPendingListingsProvider);
  }

  Future<void> _approveOwner(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Setujui owner',
      message:
          'Verifikasi "${row['profile']?['full_name'] ?? '—'}" sebagai owner terverifikasi?',
      confirmLabel: 'Setujui',
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminRepositoryProvider).approveOwner('${row['user_id']}');
      _invalidate(ref);
      snack(messenger, 'Owner terverifikasi.');
    } catch (_) {
      snack(messenger, 'Gagal memverifikasi owner.');
    }
  }

  Future<void> _rejectOwner(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
  ) async {
    final reason = await askReason(
      context,
      title: 'Tolak verifikasi owner',
      hint: 'Alasan penolakan (wajib)',
    );
    if (reason == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminRepositoryProvider)
          .rejectOwner('${row['user_id']}', reason);
      _invalidate(ref);
      snack(messenger, 'Verifikasi owner ditolak.');
    } catch (_) {
      snack(messenger, 'Gagal menolak verifikasi.');
    }
  }

  Future<void> _ownerDetail(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
  ) async {
    final docPath = row['doc_path'] as String?;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${row['profile']?['full_name'] ?? 'Owner'}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Telepon: ${row['profile']?['phone'] ?? '—'}'),
                Text('Dikirim: ${_fmtDate(row['submitted_at'])}'),
                Text('Status akun: ${row['profile']?['status'] ?? '—'}'),
                const SizedBox(height: 12),
                if (docPath == null)
                  const Text('Tidak ada dokumen terlampir.')
                else
                  FutureBuilder<String>(
                    future: ref
                        .read(adminRepositoryProvider)
                        .signedDocUrl(docPath),
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: LinearProgressIndicator(),
                        );
                      }
                      if (snap.hasError) {
                        return const Text('Gagal memuat dokumen.');
                      }
                      final url = snap.data!;
                      if (RegExp(
                        r'\.(png|jpe?g|webp)$',
                        caseSensitive: false,
                      ).hasMatch(docPath)) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dokumen verifikasi:'),
                            const SizedBox(height: 8),
                            InteractiveViewer(
                              child: Image.network(
                                url,
                                height: 220,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, st) =>
                                    const Text('Gambar gagal dimuat.'),
                              ),
                            ),
                          ],
                        );
                      }
                      return SelectableText('Tautan dokumen (PDF):\n$url');
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _rejectOwner(context, ref, row);
            },
            child: const Text('Tolak'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _approveOwner(context, ref, row);
            },
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
  }

  Future<void> _listingDetail(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
  ) async {
    final wasDraft = row['listing_status'] == 'draft';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${row['name']}'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pemilik: ${row['owner']?['full_name'] ?? '—'}'),
            Text('Telepon: ${row['owner']?['phone'] ?? '—'}'),
            Text('Alamat: ${row['address'] ?? '—'}'),
            Text('Status: ${row['listing_status']}'),
            Text('Diajukan: ${_fmtDate(row['created_at'])}'),
            if (wasDraft)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Setujui → listing langsung aktif dan tampil publik.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _rejectListing(context, ref, row);
            },
            child: const Text('Tolak'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _approveListing(context, ref, row, wasDraft: wasDraft);
            },
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveListing(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row, {
    required bool wasDraft,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminRepositoryProvider)
          .approveListing('${row['id']}', wasDraft: wasDraft);
      _invalidate(ref);
      snack(messenger, 'Listing disetujui.');
    } catch (_) {
      snack(messenger, 'Gagal menyetujui listing.');
    }
  }

  Future<void> _rejectListing(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
  ) async {
    final reason = await askReason(
      context,
      title: 'Tolak listing',
      hint: 'Alasan penolakan (wajib)',
    );
    if (reason == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminRepositoryProvider)
          .rejectListing('${row['id']}', reason);
      _invalidate(ref);
      snack(messenger, 'Listing ditolak.');
    } catch (_) {
      snack(messenger, 'Gagal menolak listing.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owners = ref.watch(adminPendingOwnersProvider);
    final listings = ref.watch(adminPendingListingsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Verifikasi'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Owner'),
              Tab(text: 'Listing'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- Owner ---
            owners.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Gagal memuat antrian owner.'),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () =>
                          ref.invalidate(adminPendingOwnersProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Text('Tidak ada verifikasi owner tertunda.'),
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(adminPendingOwnersProvider),
                      child: ListView(
                        children: [
                          for (final row in list)
                            ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(
                                '${row['profile']?['full_name'] ?? '—'}',
                              ),
                              subtitle: Text(
                                '${row['profile']?['phone'] ?? '—'} · '
                                'dikirim ${_fmtDate(row['submitted_at'])}'
                                '${row['doc_path'] == null ? ' · tanpa dokumen' : ' · dokumen terlampir'}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _ownerDetail(context, ref, row),
                            ),
                        ],
                      ),
                    ),
            ),
            // --- Listing ---
            listings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Gagal memuat antrian listing.'),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () =>
                          ref.invalidate(adminPendingListingsProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('Tidak ada listing tertunda.'))
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(adminPendingListingsProvider),
                      child: ListView(
                        children: [
                          for (final row in list)
                            ListTile(
                              leading: const Icon(Icons.home_outlined),
                              title: Text('${row['name']}'),
                              subtitle: Text(
                                '${row['owner']?['full_name'] ?? '—'} · '
                                '${row['address'] ?? '—'}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _listingDetail(context, ref, row),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
