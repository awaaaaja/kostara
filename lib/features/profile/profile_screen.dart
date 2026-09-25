import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_repository.dart';
import '../auth/tos_summary.dart';
import '../owner/owner_verification_section.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// Tarik/beri persetujuan data interaksi (cp02-privacy §3); event baru
  /// mengikuti `data_consent_at` via guard server-side.
  Future<void> _setDataConsent(
    BuildContext context,
    WidgetRef ref,
    String userId,
    bool enabled,
  ) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'data_consent_at': enabled
                ? DateTime.now().toUtc().toIso8601String()
                : null,
          })
          .eq('id', userId);
      ref.invalidate(currentProfileProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memperbarui izin. Coba lagi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text('Gagal memuat profil.'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(currentProfileProvider),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
        data: (p) {
          if (p == null) {
            return const Center(child: Text('Profil tidak ditemukan.'));
          }
          final roleLabel = switch (p.role) {
            'owner' => 'Pemilik kos',
            'super_admin' => 'Super admin',
            _ => 'Pencari kos',
          };
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      p.fullName.isEmpty
                          ? '?'
                          : p.fullName.trim()[0].toUpperCase(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.fullName.isEmpty ? 'Tanpa nama' : p.fullName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            p.isOwner
                                ? Icons.business_outlined
                                : Icons.person_outline,
                            size: 16,
                          ),
                          label: Text(roleLabel),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: scheme.surfaceContainerLow,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Syarat & Ketentuan'),
                      subtitle: Text(
                        p.tosVersion.isEmpty
                            ? 'Belum tercatat'
                            : 'Diterima ${p.tosVersion}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showTosSummarySheet(context),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: Icon(
                        p.hasDataConsent
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                      ),
                      title: const Text('Izin data personalisasi'),
                      subtitle: Text(
                        p.hasDataConsent
                            ? 'Aktif — rekomendasi dapat dipersonalisasi'
                            : 'Nonaktif — rekomendasi memakai dasar umum',
                      ),
                      value: p.hasDataConsent,
                      onChanged: (v) => _setDataConsent(context, ref, p.id, v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (p.isOwner) ...[
                const OwnerVerificationSection(),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Keluar'),
              ),
              const SizedBox(height: 24),
              _DeleteAccountSection(profileId: p.id),
            ],
          );
        },
      ),
    );
  }
}

/// Zona berbahaya: hapus akun (anonymize + cabut sesi). Konfirmasi ganda;
/// alasan server (mis. tenancy aktif) ditampilkan apa adanya.
class _DeleteAccountSection extends ConsumerStatefulWidget {
  const _DeleteAccountSection({required this.profileId});

  final String profileId;

  @override
  ConsumerState<_DeleteAccountSection> createState() =>
      _DeleteAccountSectionState();
}

class _DeleteAccountSectionState extends ConsumerState<_DeleteAccountSection> {
  bool _busy = false;

  Future<void> _delete() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus akun?'),
        content: const Text(
          'Data pribadi akan dianonimkan, sesi keluar, dan kamu tidak bisa '
          'masuk kembali. Riwayat interaksi tetap disimpan anonim. '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus permanen'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      // signOut memicu redirect router ke /login.
      messenger.showSnackBar(
        const SnackBar(content: Text('Akun berhasil dihapus.')),
      );
    } catch (e) {
      final msg = '$e'.contains('tenancy_masih_aktif')
          ? 'Masih ada sewa aktif — akun tidak dapat dihapus.'
          : 'Gagal menghapus akun. Coba lagi.';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: scheme.outlineVariant),
        const SizedBox(height: 8),
        Text(
          'Zona berbahaya',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: scheme.error),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _delete,
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.error,
            side: BorderSide(color: scheme.error),
          ),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_forever_outlined),
          label: Text(_busy ? 'Menghapus…' : 'Hapus akun'),
        ),
      ],
    );
  }
}
