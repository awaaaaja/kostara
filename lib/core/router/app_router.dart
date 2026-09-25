import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/router/app_shell.dart';
import '../../features/auth/auth_repository.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/compare/compare_screen.dart';
import '../../features/discovery/explore_map_screen.dart';
import '../../features/discovery/home_feed_screen.dart';
import '../../features/discovery/property_list_screen.dart';
import '../../features/owner/add_property_screen.dart';
import '../../features/owner/owner_dashboard_screen.dart';
import '../../features/owner/owner_payments_screen.dart';
import '../../features/owner/owner_properties_screen.dart';
import '../../features/owner/owner_property_manage_screen.dart';
import '../../features/owner/owner_tenants_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/property_detail/property_detail_screen.dart';
import '../../features/feedback/review_submit_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/admin/admin_master_screen.dart';
import '../../features/admin/admin_moderation_screen.dart';
import '../../features/admin/admin_verify_screen.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/tenancy/payment_history_screen.dart';
import '../../features/tenancy/reminder_setup_screen.dart';
import '../../features/tenancy/tenancy_screen.dart';

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<AuthState> stream) {
    _sub = stream.skip(1).listen((_) => notifyListeners());
  }

  StreamSubscription<AuthState>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Route yang hanya untuk pemilik (A7 admin menyusul CP-04B).
bool _isOwnerPath(String location) => location.startsWith('/owner');

/// Route operasi super admin (FR-ADM-*).
bool _isAdminPath(String location) => location.startsWith('/admin');

/// Tab seeker yang tidak relevan untuk owner (DESIGN §11 vs §12).
bool _isSeekerOnlyPath(String location) =>
    location == '/home' || location == '/saved' || location == '/tenancy';

final routerProvider = Provider<GoRouter>((ref) {
  if (!AppConfig.hasSupabase) {
    // Repo tetap bisa dites tanpa konfigurasi (foundation CP-00).
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(
              child: Text(
                'Foundation ready. Configure Supabase via --dart-define.',
              ),
            ),
          ),
        ),
      ],
    );
  }

  final authRepo = ref.watch(authRepositoryProvider);
  final refresh = _AuthRefresh(authRepo.authStates);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onAuthPage = location == '/login' || location == '/register';
      final loggedIn = authRepo.currentUser != null;
      if (!loggedIn) return onAuthPage ? null : '/login';
      if (onAuthPage) return '/home';
      // Role guard bila profil sudah diketahui; bila belum, AppShell yang
      // mengarahkan setelah profil termuat.
      final profile = ref.read(currentProfileProvider).valueOrNull;
      if (profile != null) {
        if (_isAdminPath(location) && !profile.isAdmin) return '/home';
        if (_isOwnerPath(location) && !profile.isOwner) return '/home';
        if (profile.isAdmin && _isSeekerOnlyPath(location)) return '/admin';
        if (profile.isOwner && _isSeekerOnlyPath(location)) return '/owner';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // --- seeker (DESIGN §11) ---
          GoRoute(path: '/home', builder: (c, s) => const HomeFeedScreen()),
          GoRoute(
            path: '/explore',
            builder: (c, s) => const PropertyListScreen(),
          ),
          GoRoute(path: '/map', builder: (c, s) => const ExploreMapScreen()),
          GoRoute(path: '/saved', builder: (c, s) => const SavedScreen()),
          GoRoute(path: '/tenancy', builder: (c, s) => const TenancyScreen()),
          GoRoute(
            path: '/tenancy/:id/reminders',
            builder: (c, s) =>
                ReminderSetupScreen(tenancyId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/tenancy/:id/payments',
            builder: (c, s) =>
                PaymentHistoryScreen(tenancyId: s.pathParameters['id']!),
          ),
          GoRoute(path: '/compare', builder: (c, s) => const CompareScreen()),
          GoRoute(
            path: '/property/:id',
            builder: (c, s) =>
                PropertyDetailScreen(propertyId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/property/:id/review',
            builder: (c, s) =>
                ReviewSubmitScreen(propertyId: s.pathParameters['id']!),
          ),
          // --- super admin (DESIGN §32, FR-ADM-*) ---
          GoRoute(
            path: '/admin',
            builder: (c, s) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/verify',
            builder: (c, s) => const AdminVerifyScreen(),
          ),
          GoRoute(
            path: '/admin/moderation',
            builder: (c, s) => const AdminModerationScreen(),
          ),
          GoRoute(
            path: '/admin/master',
            builder: (c, s) => const AdminMasterScreen(),
          ),
          // --- owner (DESIGN §12) ---
          GoRoute(
            path: '/owner',
            builder: (c, s) => const OwnerDashboardScreen(),
          ),
          GoRoute(
            path: '/owner/properties',
            builder: (c, s) => const OwnerPropertiesScreen(),
          ),
          GoRoute(
            path: '/owner/properties/:id',
            builder: (c, s) =>
                OwnerPropertyManageScreen(propertyId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/owner/tenants',
            builder: (c, s) => const OwnerTenantsScreen(),
          ),
          GoRoute(
            path: '/owner/payments',
            builder: (c, s) => const OwnerPaymentsScreen(),
          ),
          GoRoute(
            path: '/owner/add',
            builder: (c, s) => const AddPropertyScreen(),
          ),
          // --- bersama ---
          GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
