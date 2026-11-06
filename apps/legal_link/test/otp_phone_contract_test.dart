import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:legal_link/features/auth/data/supabase_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final phone in [
    '1700000099',
    '01700000099',
    '8801700000099',
    '+8801700000099',
  ]) {
    test(
      'OTP request and verification use the same E.164 phone for $phone',
      () async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'public-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              request.url.path.endsWith('/otp')
                  ? '{}'
                  : '{"code":400,"error_code":"otp_expired","msg":"Test OTP"}',
              request.url.path.endsWith('/otp') ? 200 : 400,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        final repository = SupabaseAuthRepository(client);
        await repository.sendOtp(phone);
        await expectLater(
          repository.verifyOtp(phone: phone, otp: '123456'),
          throwsA(isA<Exception>()),
        );
        expect(requests, hasLength(2));
        for (final request in requests) {
          expect(jsonDecode(request.body)['phone'], '+8801700000099');
        }
      },
    );
  }
}
