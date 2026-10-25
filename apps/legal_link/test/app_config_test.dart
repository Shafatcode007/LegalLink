import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/core/env/app_config.dart';

void main() {
  group('AppConfig', () {
    test('has no backend by default', () {
      expect(const AppConfig().hasSupabase, isFalse);
    });

    test('needs both the URL and the key', () {
      expect(
        const AppConfig(supabaseUrl: 'https://x.supabase.co').hasSupabase,
        isFalse,
      );
      expect(
        const AppConfig(
          supabaseUrl: 'https://x.supabase.co',
          supabaseAnonKey: 'k',
        ).hasSupabase,
        isTrue,
      );
    });
  });
}
