import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_repository.dart';
import 'owner_repository.dart';

/// Kartu status verifikasi pemilik + unggah dokumen (KTP/foto) ke bucket
/// privat `verification-documents-private` lalu ajukan/ajukan ulang.
class OwnerVerificationSection extends ConsumerStatefulWidget {
  const OwnerVerificationSection({super.key});

  @override
  ConsumerState<OwnerVerificationSection> createState() =>
      _OwnerVerificationSectionState();
}

class _OwnerVerificationSectionState
    extends ConsumerState<OwnerVerificationSection> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final ext = picked.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final path =
          '${profile.id}/dokumen-${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Supabase.instance.client.storage
          .from('verification-documents-private')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      await ref.read(ownerRepositoryProvider).submitVerification(path);
      ref.invalidate(ownerVerificationProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Dokumen dikirim untuk verifikasi.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Gagal mengunggah. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verification = ref.watch(ownerVerificationProvider);
    final scheme = Theme.of(context).colorScheme;

    return verification.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (row) {
        final status = '${row?['verification_status'] ?? 'pending'}';
        final (label, color) = switch (status) {
          'verified' => ('Terverifikasi', scheme.primary),
          'rejected' => ('Ditolak', scheme.error),
          'suspended' => ('Ditangguhkan', scheme.error),
          _ => ('Menunggu verifikasi', scheme.tertiary),
        };
        return Card(
          elevation: 0,
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.badge_outlined, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verifikasi pemilik',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(label, style: TextStyle(color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(switch (status) {
                  'verified' => 'Identitasmu sudah diverifikasi admin.',
                  'rejected' =>
                    'Ditolak: ${row?['reject_reason'] ?? '-'} — perbaiki lalu unggah ulang.',
                  'pending' => 'Dokumen sedang ditinjau admin.',
                  _ => 'Unggah ulang dokumen identitas.',
                }, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _uploading ? null : _pickAndUpload,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(
                    row?['doc_path'] == null
                        ? 'Unggah dokumen'
                        : 'Unggah ulang',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
