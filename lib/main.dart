import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Foundation only (CP-00): initialize Supabase when configured.
  // App boots without configuration so the repo stays reproducible.
  if (AppConfig.hasSupabase) {
    AppConfig.assertNoServiceRole();
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  runApp(const KostaraApp());
}

class KostaraApp extends StatelessWidget {
  const KostaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KOSTARA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B52)),
        useMaterial3: true,
      ),
      home: const _FoundationHome(),
    );
  }
}

class _FoundationHome extends StatelessWidget {
  const _FoundationHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KOSTARA')),
      body: Center(
        child: Text(
          AppConfig.hasSupabase
              ? 'Foundation ready (Supabase configured).'
              : 'Foundation ready. Configure Supabase via --dart-define.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
