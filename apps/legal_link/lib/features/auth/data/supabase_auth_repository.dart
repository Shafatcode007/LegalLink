import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_user.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/user_role.dart';

class SupabaseAuthRepository implements AuthRepository, AuthSessionChanges {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  @override
  Stream<void> get signedOut => _client.auth.onAuthStateChange
      .where((event) => event.event == AuthChangeEvent.signedOut)
      .map((_) {});

  @override
  Future<void> sendOtp(String phone) =>
      _client.auth.signInWithOtp(phone: phone);

  @override
  Future<void> verifyOtp({required String phone, required String otp}) async {
    try {
      await _client.auth.verifyOTP(phone: phone, token: otp, type: OtpType.sms);
    } on AuthException catch (error) {
      if (error.code == 'otp_expired' || error.code == 'otp_disabled') {
        throw const AuthFailure('Invalid OTP');
      }
      rethrow;
    }
  }

  @override
  Future<String?> getVerifiedPhone() async => _client.auth.currentUser?.phone;

  @override
  Future<void> completeSignup({
    required UserRole role,
    required String fullName,
    required String language,
  }) async {
    // Phone is resolved by complete_signup from auth.users, never from Flutter.
    await _client.rpc(
      'complete_signup',
      params: {
        'p_role': role.value,
        'p_full_name': fullName.trim(),
        'p_language': language,
      },
    );
    await _client.auth.refreshSession();
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return null;
    final row = await _client
        .from('profiles')
        .select('id,phone,full_name,language,role')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    final role = switch (row['role']) {
      'client' => UserRole.client,
      'advocate' => UserRole.advocate,
      _ => throw const AuthFailure('Unsupported account'),
    };
    final phone = row['phone'] as String;
    return AppUser(
      id: row['id'] as String,
      phone: phone.startsWith('+') ? phone : '+$phone',
      fullName: row['full_name'] as String,
      language: row['language'] as String,
      role: role,
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
