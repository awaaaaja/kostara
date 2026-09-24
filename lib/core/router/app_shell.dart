import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_repository.dart';
import '../../features/discovery/discovery_providers.dart';
import '../../features/onboarding/onboarding_screen.dart';

/// Navigasi utama + gate: auth (router), profil, onboarding seeker.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

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

        var body = child;
        var onboarded = true;
        if (!p.isOwner) {
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
            data: (has) {
              if (has) return child;
              onboarded = false;
              return const OnboardingScreen();
            },
          );
          if (!onboarded) {
            return Scaffold(body: body);
          }
        }

        final location = GoRouterState.of(context).matchedLocation;
        final selectedIndex = switch (location) {
          '/map' => 1,
          '/owner/add' => 2,
          _ => 0,
        };

        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex < (p.isOwner ? 3 : 2)
                ? selectedIndex
                : 0,
            onDestinationSelected: (i) {
              if (i == 0) {
                context.go('/explore');
              } else if (i == 1) {
                context.go('/map');
              } else {
                context.go('/owner/add');
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Cari kos',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Peta',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_business_outlined),
                selectedIcon: Icon(Icons.add_business),
                label: 'Kelola',
              ),
            ],
          ),
        );
      },
    );
  }
}
