import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/events/event_logger.dart';
import '../compare/compare_state.dart';
import '../discovery/discovery_providers.dart';
import '../discovery/discovery_repository.dart';
import '../feedback/feedback_repository.dart';
import '../saved/favorites_repository.dart';
import '../tenancy/tenancy_repository.dart';
import '../auth/auth_repository.dart';

final _detailProvider = FutureProvider.family<Map<String, dynamic>, String>((
  ref,
  id,
) async {
  final data = await ref.watch(discoveryProvider).propertyDetail(id);
  ref.watch(eventLoggerProvider).log('property_view', propertyId: id);
  return data;
});

final _roomsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
      (ref, id) => ref.watch(discoveryProvider).propertyRooms(id),
    );

class PropertyDetailScreen extends ConsumerWidget {
  const PropertyDetailScreen({super.key, required this.propertyId});

  final String propertyId;

  String? _coverUrl(dynamic images) {
    if (images is! List || images.isEmpty) return null;
    final sorted = [...images]
      ..sort((a, b) {
        final ai = (a['is_cover'] == true) ? 1 : 0;
        final bi = (b['is_cover'] == true) ? 1 : 0;
        if (ai != bi) return bi - ai;
        return ((b['sort_order'] ?? 0) as num).compareTo(
          (a['sort_order'] ?? 0) as num,
        );
      });
    final path = sorted.first['storage_path'] as String?;
    if (path == null) return null;
    return Supabase.instance.client.storage
        .from('property-images')
        .getPublicUrl(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_detailProvider(propertyId));
    final rooms = ref.watch(_roomsProvider(propertyId));
    final reviews = ref.watch(propertyDetailReviewsProvider(propertyId));
    final favoriteIds = ref.watch(favoriteIdsProvider).valueOrNull ?? const [];
    final compareIds = ref.watch(compareIdsProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final saved = favoriteIds.contains(propertyId);
    final inCompare = compareIds.contains(propertyId);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail kos')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                e is StateError
                    ? 'Kos tidak ditemukan.'
                    : 'Gagal memuat detail.',
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(_detailProvider(propertyId)),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
        data: (data) {
          final cover = _coverUrl(data['property_images']);
          final facilities =
              (data['property_facilities'] as List?)
                  ?.map((e) => '${e['facilities']?['name']}')
                  .toList() ??
              const <String>[];
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              SizedBox(
                height: 200,
                width: double.infinity,
                child: cover == null
                    ? ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.home_outlined, size: 48),
                      )
                    : Image.network(
                        cover,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, st) => ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data['name']}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data['address'] ?? ''}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.person_outline, size: 16),
                          label: Text(_genderLabel('${data['gender_policy']}')),
                        ),
                        Chip(
                          avatar: const Icon(Icons.verified_outlined, size: 16),
                          label: Text('${data['verification_status']}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => toggleFavorite(ref, propertyId),
                            icon: Icon(
                              saved ? Icons.favorite : Icons.favorite_border,
                              size: 18,
                              color: saved ? scheme.error : null,
                            ),
                            label: Text(saved ? 'Tersimpan' : 'Simpan'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final msg = inCompare
                                  ? null
                                  : ref
                                        .read(compareIdsProvider.notifier)
                                        .add(propertyId);
                              if (msg != null) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(msg)));
                              } else if (!inCompare) {
                                ref
                                    .read(eventLoggerProvider)
                                    .log('compare_add', propertyId: propertyId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Ditambahkan ke perbandingan',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: Icon(
                              inCompare
                                  ? Icons.check_box
                                  : Icons.compare_arrows,
                              size: 18,
                            ),
                            label: Text(
                              inCompare ? 'Dibandingkan' : 'Bandingkan',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 8),
                    if (data['description'] != null)
                      Text('${data['description']}'),
                    if (facilities.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Fasilitas',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in facilities) Chip(label: Text(f)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Kamar',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    rooms.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(8),
                        child: LinearProgressIndicator(),
                      ),
                      error: (e, _) => const Text('Gagal memuat kamar.'),
                      data: (list) => list.isEmpty
                          ? const Text('Belum ada data kamar.')
                          : Column(
                              children: [
                                for (final r in list)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.meeting_room_outlined,
                                    ),
                                    title: Text(
                                      '${r['code']} · ${r['room_type']}',
                                    ),
                                    subtitle: Text('Rp${r['price']} / bulan'),
                                    trailing:
                                        r['status'] == 'available' &&
                                            _canRequest(profile, data)
                                        ? FilledButton.tonal(
                                            style: FilledButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            onPressed: () => _showRequestDialog(
                                              context,
                                              ref,
                                              r['id'] as String,
                                            ),
                                            child: const Text('Ajukan'),
                                          )
                                        : Chip(
                                            label: Text('${r['status']}'),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ulasan terverifikasi',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (profile != null &&
                            !profile.isOwner &&
                            !profile.isAdmin)
                          TextButton(
                            onPressed: () =>
                                context.push('/property/$propertyId/review'),
                            child: const Text('Tulis ulasan'),
                          ),
                      ],
                    ),
                    reviews.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(8),
                        child: LinearProgressIndicator(),
                      ),
                      error: (e, _) => const Text('Gagal memuat ulasan.'),
                      data: (list) {
                        if (list.isEmpty) {
                          return const Text('Belum ada ulasan.');
                        }
                        final avg =
                            list
                                .map(
                                  (r) =>
                                      (r['rating_overall'] as num).toDouble(),
                                )
                                .reduce((a, b) => a + b) /
                            list.length;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${avg.toStringAsFixed(1)} dari 5 · '
                              '${list.length} ulasan',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 4),
                            for (final r in list)
                              _ReviewItem(review: r, propertyId: propertyId),
                            TextButton.icon(
                              onPressed: () => _showReportDialog(
                                context,
                                ref,
                                targetType: 'property',
                                targetId: propertyId,
                              ),
                              icon: const Icon(Icons.flag_outlined, size: 18),
                              label: const Text('Laporkan listing ini'),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _canRequest(AppProfile? profile, Map<String, dynamic> data) {
    if (profile == null || profile.isOwner) return false;
    return data['owner_id'] != profile.id;
  }

  Future<void> _showRequestDialog(
    BuildContext context,
    WidgetRef ref,
    String roomId,
  ) async {
    final message = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajukan sewa'),
        content: TextField(
          controller: message,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Pesan untuk pemilik (opsional)',
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
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(tenancyRepositoryProvider)
          .submitRequest(
            propertyId: propertyId,
            roomId: roomId,
            message: message.text,
          );
      ref
          .read(eventLoggerProvider)
          .log('tenancy_request', propertyId: propertyId);
      ref.invalidate(myTenancyRequestsProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Permintaan sewa dikirim.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyTenancyError(e))));
    } finally {
      message.dispose();
    }
  }

  String _genderLabel(String v) => switch (v) {
    'male_only' => 'Putra',
    'female_only' => 'Putri',
    _ => 'Campur',
  };
}

/// Satu review publik: tanpa identitas penuh (AC-REV-06) — hanya label
/// "Penghuni terverifikasi • Bulan Tahun" + skor aspek + aksi laporkan.
class _ReviewItem extends ConsumerWidget {
  const _ReviewItem({required this.review, required this.propertyId});

  final Map<String, dynamic> review;
  final String propertyId;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  String get _monYear {
    final d = DateTime.tryParse('${review['created_at']}');
    if (d == null) return '';
    final local = d.toLocal();
    return '${_months[local.month - 1]} ${local.year}';
  }

  String get _aspectLine {
    final scores = (review['review_aspect_scores'] as List?) ?? const [];
    if (scores.isEmpty) return '';
    final labels = {for (final (k, v) in kReviewAspects) k: v};
    return scores
        .map((s) {
          final m = s as Map<String, dynamic>;
          final label = labels['${m['aspect']}'] ?? '${m['aspect']}';
          return '$label ${m['score'] ?? '—'}';
        })
        .join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = '${review['review_text'] ?? ''}';
    final aspects = _aspectLine;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.star_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        'Penghuni terverifikasi • $_monYear',
        style: Theme.of(context).textTheme.labelMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text.isNotEmpty) Text(text),
          if (aspects.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                aspects,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Opsi review',
        onSelected: (reason) => _showReportDialog(
          context,
          ref,
          targetType: 'review',
          targetId: '${review['id']}',
          presetReason: reason,
        ),
        itemBuilder: (_) => [
          for (final (code, label) in kReportReasons)
            PopupMenuItem(value: code, child: Text('Laporkan: $label')),
        ],
      ),
    );
  }
}

/// Dialog laporan (review/listing) — alasan + detail opsional (FR-ADM laporan).
Future<void> _showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required String targetId,
  String? presetReason,
}) async {
  var reason = presetReason ?? kReportReasons.first.$1;
  final detailCtrl = TextEditingController();
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(
          targetType == 'review' ? 'Laporkan ulasan' : 'Laporkan listing',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<String>(
              groupValue: reason,
              onChanged: (v) => setDialogState(() => reason = v ?? reason),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (code, label) in kReportReasons)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(label),
                      value: code,
                    ),
                ],
              ),
            ),
            TextField(
              controller: detailCtrl,
              maxLines: 2,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'Keterangan tambahan (opsional)',
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
            child: const Text('Kirim laporan'),
          ),
        ],
      ),
    ),
  );
  try {
    if (ok != true) return;
    await ref
        .read(feedbackRepositoryProvider)
        .submitReport(
          targetType: targetType,
          targetId: targetId,
          reasonCode: reason,
          detail: detailCtrl.text,
        );
    messenger.showSnackBar(
      const SnackBar(content: Text('Laporan terkirim. Terima kasih.')),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Gagal mengirim laporan. Coba lagi.')),
    );
  } finally {
    detailCtrl.dispose();
  }
}
