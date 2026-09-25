import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Foundation (CP-00): initialize Supabase when configured.
  // App boots without configuration so the repo stays reproducible.
  if (AppConfig.hasSupabase) {
    AppConfig.assertNoServiceRole();
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  runApp(const ProviderScope(child: KostaraApp()));
}

class KostaraApp extends ConsumerWidget {
  const KostaraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'KOSTARA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B52)),
        useMaterial3: true,
        // DESAIN §2 (R-022): Plus Jakarta Sans dibundel via pubspec fonts.
        fontFamily: 'PlusJakartaSans',
      ),
      routerConfig: router,
    );
  }
}
