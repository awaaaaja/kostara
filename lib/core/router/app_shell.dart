import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_repository.dart';
import '../../features/discovery/discovery_providers.dart';
import '../../features/onboarding/onboarding_screen.dart';

/// Tab seeker yang tidak relevan untuk pendaratan admin (router juga
/// mengarahkan; sini untuk kasus profil baru diketahui).
bool _isSeekerPath(String location) =>
    location == '/home' ||
    location == '/saved' ||
    location == '/tenancy' ||
    location == '/compare';

/// Navigasi utama + gate: auth (router), profil, onboarding seeker.
/// Tab mengikuti role (DESIGN §11 seeker / §12 owner).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _seekerTabs = [
    (
      icon: Icons.home_outlined,
      selected: Icons.home,
      label: 'Beranda',
      path: '/home',
    ),
    (
      icon: Icons.explore_outlined,
      selected: Icons.explore,
      label: 'Cari',
      path: '/explore',
    ),
    (
      icon: Icons.favorite_outline,
      selected: Icons.favorite,
      label: 'Tersimpan',
      path: '/saved',
    ),
    (
      icon: Icons.key_outlined,
      selected: Icons.key,
      label: 'Sewa',
      path: '/tenancy',
    ),
    (
      icon: Icons.person_outline,
      selected: Icons.person,
      label: 'Profil',
      path: '/profile',
    ),
  ];

  static const _ownerTabs = [
    (
      icon: Icons.dashboard_outlined,
      selected: Icons.dashboard,
      label: 'Ringkasan',
      path: '/owner',
    ),
    (
      icon: Icons.home_work_outlined,
      selected: Icons.home_work,
      label: 'Properti',
      path: '/owner/properties',
    ),
    (
      icon: Icons.groups_outlined,
      selected: Icons.groups,
      label: 'Penyewa',
      path: '/owner/tenants',
    ),
    (
      icon: Icons.receipt_long_outlined,
      selected: Icons.receipt_long,
      label: 'Bayar',
      path: '/owner/payments',
    ),
    (
      icon: Icons.person_outline,
      selected: Icons.person,
      label: 'Profil',
      path: '/profile',
    ),
  ];

  static const _adminTabs = [
    (
      icon: Icons.dashboard_outlined,
      selected: Icons.dashboard,
      label: 'Ringkasan',
      path: '/admin',
    ),
    (
      icon: Icons.verified_user_outlined,
      selected: Icons.verified_user,
      label: 'Verifikasi',
      path: '/admin/verify',
    ),
    (
      icon: Icons.rule_outlined,
      selected: Icons.rule,
      label: 'Moderasi',
      path: '/admin/moderation',
    ),
    (
      icon: Icons.storage_outlined,
      selected: Icons.storage,
      label: 'Data',
      path: '/admin/master',
    ),
  ];

  int _indexOf(String location, bool isOwner, bool isAdmin) {
    if (isAdmin) {
      if (location.startsWith('/admin/verify')) return 1;
      if (location.startsWith('/admin/moderation')) return 2;
      if (location.startsWith('/admin/master')) return 3;
      return 0;
    }
    if (isOwner) {
      if (location.startsWith('/owner/properties') ||
          location.startsWith('/owner/add')) {
        return 1;
      }
      if (location.startsWith('/owner/tenants')) return 2;
      if (location.startsWith('/owner/payments')) return 3;
      if (location == '/profile') return 4;
      return 0;
    }
    if (location == '/profile') return 4;
    if (location == '/saved' || location == '/compare') return 3;
    if (location == '/tenancy') return 2;
    if (location == '/home') return 0;
    return 1; // /explore, /map, /property/:id
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return profile.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(
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
      ),
      data: (p) {
        if (p == null) {
          // Menunggu redirect auth.
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final location = GoRouterState.of(context).matchedLocation;

        // Kendali pendaratan lintas role (profil baru diketahui setelah
        // redirect router berjalan).
        if (p.isAdmin && _isSeekerPath(location)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/admin');
          });
        } else if (!p.isAdmin && location.startsWith('/admin')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go(p.isOwner ? '/owner' : '/home');
          });
        } else if (p.isOwner &&
            (location == '/home' ||
                location == '/saved' ||
                location == '/tenancy')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/owner');
          });
        } else if (!p.isOwner && location.startsWith('/owner')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go(p.isAdmin ? '/admin' : '/home');
          });
        }

        var body = child;
        if (!p.isOwner && !p.isAdmin) {
          final prefs = ref.watch(hasPrefsProvider);
          body = prefs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal memuat preferensi.'),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(hasPrefsProvider),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
            data: (has) => has ? child : const OnboardingScreen(),
          );
          if (body is OnboardingScreen) {
            // Onboarding tanpa tab (alur satu langkah).
            return Scaffold(body: body);
          }
        }

        final tabs = p.isAdmin
            ? _adminTabs
            : (p.isOwner ? _ownerTabs : _seekerTabs);
        final selectedIndex = _indexOf(location, p.isOwner, p.isAdmin);

        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => context.go(tabs[i].path),
            destinations: [
              for (final t in tabs)
                NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.selected),
                  label: t.label,
                ),
            ],
          ),
        );
      },
    );
  }
}
