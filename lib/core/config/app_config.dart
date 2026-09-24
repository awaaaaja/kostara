/// Build-time configuration. Values are passed via `--dart-define`:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
/// ```
///
/// Real values live locally in Aman.md (git-ignored). Never hardcode
/// secrets here and never use a service_role key in the app.
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static void assertNoServiceRole() {
    assert(
      !supabaseAnonKey.toLowerCase().contains('service_role'),
      'service_role key must never be bundled in the Flutter app',
    );
  }
}
