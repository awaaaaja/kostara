import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/feedback/feedback_repository.dart';
import 'admin_dialogs.dart';
import 'admin_repository.dart';

/// Moderasi laporan & ulasan (FR-ADM-03, AC-ADM-04): resolve dengan
/// catatan; review approve/reject/hide — reject wajib alasan, hide hanya
/// flag (isi review asli tidak pernah diubah).
class AdminModerationScreen extends ConsumerWidget {
  const AdminModerationScreen({super.key});

  String _fmtDate(Object? v) {
    if (v == null) return '—';
    final d = DateTime.tryParse('$v');
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _reasonLabel(String code) {
    for (final (k, v) in kReportReasons) {
      if (k == code) return v;
    }
    return code;
  }

  Future<void> _resolveReport(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
  ) async {
    var status = 'resolved';
    final noteCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Tindak laporan'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_reasonLabel('${row['reason_code']}')),
              Text(
                '${row['target_type']} · dikirim '
                '${_fmtDate(row['created_at'])}',
                style: Theme.of(dialogContext).textTheme.labelSmall,
              ),
              if ('${row['detail'] ?? ''}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${row['detail']}'),
                ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: status,
                onChanged: (v) => setDialogState(() => status = v ?? status),
                child: Column(
                  children: [
                    const RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('Selesaikan (laporan valid)'),
                      value: 'resolved',
                    ),
                    const RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('Tolak laporan'),
                      value: 'rejected',
                    ),
                  ],
                ),
              ),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                maxLength: 300,
                decoration: const InputDecoration(
                  hintText: 'Catatan penanganan (opsional)',
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .resolveReport('${row['id']}', status: status, note: noteCtrl.text);
      ref.invalidate(adminOpenReportsProvider);
      ref.invalidate(adminOverviewProvider);
      snack(messenger, 'Laporan ditangani.');
    } catch (_) {
      snack(messenger, 'Gagal menangani laporan.');
    } finally {
      noteCtrl.dispose();
    }
  }

  Future<void> _moderateReview(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row, {
    required String action,
  }) async {
    String? reason;
    if (action == 'reject') {
      reason = await askReason(
        context,
        title: 'Tolak ulasan',
        hint: 'Alasan penolakan (wajib)',
      );
      if (reason == null) return;
    } else if (action == 'hide') {
      final ok = await confirmAction(
        context,
        title: 'Sembunyikan ulasan',
        message:
            'Ulasan disembunyikan dari publik (flag saja — isi asli tetap tersimpan).',
        confirmLabel: 'Sembunyikan',
      );
      if (!ok) return;
    } else {
      final ok = await confirmAction(
        context,
        title: 'Setujui ulasan',
        message: 'Ulasan tampil publik setelah disetujui.',
        confirmLabel: 'Setujui',
      );
      if (!ok) return;
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminRepositoryProvider)
          .moderateReview('${row['id']}', action: action, reason: reason);
      ref.invalidate(adminPendingReviewsProvider);
      ref.invalidate(adminVisibleReviewsProvider);
      ref.invalidate(adminOverviewProvider);
      snack(messenger, switch (action) {
        'approve' => 'Ulasan disetujui.',
        'reject' => 'Ulasan ditolak.',
        _ => 'Ulasan disembunyikan.',
      });
    } catch (_) {
      snack(messenger, 'Gagal memoderasi ulasan.');
    }
  }

  Widget _reviewTile(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row, {
    required bool pending,
  }) {
    final aspects = (row['review_aspect_scores'] as List?) ?? const [];
    final labels = {for (final (k, v) in kReviewAspects) k: v};
    final aspectLine = aspects
        .map((s) {
          final m = s as Map<String, dynamic>;
          return '${labels['${m['aspect']}'] ?? m['aspect']} ${m['score'] ?? '—'}';
        })
        .join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        pending ? Icons.rate_review_outlined : Icons.visibility_outlined,
      ),
      title: Text(
        '${row['property']?['name'] ?? '—'} · '
        'rating ${row['rating_overall']}/5',
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ('${row['review_text'] ?? ''}'.isNotEmpty)
            Text('${row['review_text']}'),
          if (aspectLine.isNotEmpty)
            Text(aspectLine, style: Theme.of(context).textTheme.labelSmall),
          Text(
            '${_fmtDate(row['created_at'])}'
            '${pending ? '' : ' · ${row['status']}'}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Aksi moderasi',
        onSelected: (action) =>
            _moderateReview(context, ref, row, action: action),
        itemBuilder: (_) => pending
            ? const [
                PopupMenuItem(value: 'approve', child: Text('Setujui')),
                PopupMenuItem(value: 'reject', child: Text('Tolak')),
                PopupMenuItem(value: 'hide', child: Text('Sembunyikan')),
              ]
            : const [PopupMenuItem(value: 'hide', child: Text('Sembunyikan'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(adminOpenReportsProvider);
    final pending = ref.watch(adminPendingReviewsProvider);
    final visible = ref.watch(adminVisibleReviewsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Moderasi'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Laporan'),
              Tab(text: 'Ulasan'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- Laporan ---
            reports.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Gagal memuat laporan.'),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(adminOpenReportsProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('Tidak ada laporan terbuka.'))
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(adminOpenReportsProvider),
                      child: ListView(
                        children: [
                          for (final row in list)
                            ListTile(
                              leading: const Icon(Icons.flag_outlined),
                              title: Text(
                                _reasonLabel('${row['reason_code']}'),
                              ),
                              subtitle: Text(
                                '${row['target_type']} · '
                                '${row['reporter']?['full_name'] ?? '—'} · '
                                '${_fmtDate(row['created_at'])}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _resolveReport(context, ref, row),
                            ),
                        ],
                      ),
                    ),
            ),
            // --- Ulasan ---
            pending.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Center(child: Text('Gagal memuat ulasan menunggu.')),
              data: (list) => visible.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    const Center(child: Text('Gagal memuat ulasan tampil.')),
                data: (shown) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(adminPendingReviewsProvider);
                    ref.invalidate(adminVisibleReviewsProvider);
                  },
                  child: ListView(
                    children: [
                      if (list.isEmpty && shown.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Tidak ada ulasan untuk dimoderasi.'),
                        ),
                      if (list.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            'Menunggu moderasi (${list.length})',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        for (final row in list)
                          _reviewTile(context, ref, row, pending: true),
                      ],
                      if (shown.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            'Sedang tampil (${shown.length})',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        for (final row in shown)
                          _reviewTile(context, ref, row, pending: false),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
