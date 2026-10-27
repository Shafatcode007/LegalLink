abstract final class AppConfig {
  static const useSupabaseAuth =
      bool.fromEnvironment('USE_SUPABASE_AUTH') ||
      bool.fromEnvironment('USE_SUPABASE');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
