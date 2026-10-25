/// Build-time configuration (TRD §3.5 `core/env`, §15), passed with
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
/// Without both values the app runs on its offline stubs.
class AppConfig {
  const AppConfig({this.supabaseUrl = '', this.supabaseAnonKey = ''});

  factory AppConfig.fromEnvironment() => const AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  final String supabaseUrl;

  /// Public by design (TRD §9.5); never the service-role key.
  final String supabaseAnonKey;

  bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
