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
import '../../features/discovery/explore_map_screen.dart';
import '../../features/discovery/property_list_screen.dart';
import '../../features/owner/add_property_screen.dart';
import '../../features/property_detail/property_detail_screen.dart';

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
    initialLocation: '/explore',
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onAuthPage = location == '/login' || location == '/register';
      final loggedIn = authRepo.currentUser != null;
      if (!loggedIn) return onAuthPage ? null : '/login';
      if (onAuthPage) return '/explore';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/explore',
            builder: (c, s) => const PropertyListScreen(),
          ),
          GoRoute(path: '/map', builder: (c, s) => const ExploreMapScreen()),
          GoRoute(
            path: '/property/:id',
            builder: (c, s) =>
                PropertyDetailScreen(propertyId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/owner/add',
            builder: (c, s) => const AddPropertyScreen(),
          ),
        ],
      ),
    ],
  );
});
