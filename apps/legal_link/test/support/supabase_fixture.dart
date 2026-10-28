import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseFixture {
  SupabaseFixture(this.respond) {
    transport = MockClient((request) async {
      requests.add(request);
      final body = await respond(request);
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    client = SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      httpClient: transport,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  final Future<Object?> Function(http.Request request) respond;
  final requests = <http.Request>[];
  late final http.Client transport;
  late final SupabaseClient client;

  Future<void> signIn({String role = 'advocate'}) async {
    final payload = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'sub': 'user-id',
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        }),
      ),
    );
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.signature',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': 'user-id',
          'aud': 'authenticated',
          'role': 'authenticated',
          'phone': '8801712345678',
          'created_at': '2026-10-01T00:00:00Z',
          'app_metadata': {'role': role},
          'user_metadata': <String, dynamic>{},
        },
      }),
    );
  }
}
