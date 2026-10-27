import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:legal_link/features/auth/data/supabase_auth_repository.dart';
import 'package:legal_link/features/auth/domain/repositories/auth_repository.dart';
import 'package:legal_link/features/auth/domain/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('live signup sends only the agreed RPC parameters and refreshes role claims', () async {
    final requests = <http.Request>[];
    final session = {
      'access_token':
          '${base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'user-id', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature',
      'refresh_token': 'test-refresh-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': 'user-id',
        'aud': 'authenticated',
        'role': 'authenticated',
        'phone': '8801712345678',
        'created_at': '2026-10-01T00:00:00Z',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      },
    };
    var role = 'advocate';
    final client = SupabaseClient(
      'https://example.supabase.co',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = request.url.path.contains('/auth/v1/token')
            ? session
            : request.url.path.contains('/profiles')
            ? [
                {
                  'id': 'user-id',
                  'phone': '8801712345678',
                  'full_name': 'Advocate Name',
                  'language': 'bn',
                  'role': role,
                },
              ]
            : <String, dynamic>{};
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    await client.auth.setInitialSession(jsonEncode(session));
    final repository = SupabaseAuthRepository(client);
    await repository.completeSignup(
      role: UserRole.advocate,
      fullName: ' Advocate Name ',
      language: 'bn',
    );
    final signup = requests.singleWhere(
      (request) => request.url.path.endsWith('/rpc/complete_signup'),
    );
    expect(jsonDecode(signup.body), {
      'p_role': 'advocate',
      'p_full_name': 'Advocate Name',
      'p_language': 'bn',
    });
    expect(
      requests.where((request) => request.url.path.contains('/auth/v1/token')),
      hasLength(1),
    );
    final user = await repository.getCurrentUser();
    expect(user!.phone, '+8801712345678');
    expect(user.role, UserRole.advocate);
    role = 'admin';
    await expectLater(repository.getCurrentUser(), throwsA(isA<AuthFailure>()));
  });
}
