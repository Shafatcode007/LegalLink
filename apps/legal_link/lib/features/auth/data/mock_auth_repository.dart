import 'package:hive_flutter/hive_flutter.dart';

import '../domain/app_user.dart';
import '../domain/user_role.dart';
import '../domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._box);

  final Box<dynamic> _box;

  String? _pendingPhone;

  @override
  Future<void> sendOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    _pendingPhone = phone;
  }

  @override
  Future<void> verifyOtp({required String phone, required String otp}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (otp != '123456') {
      throw Exception('Invalid OTP');
    }

    _pendingPhone = phone;

    await _box.put('authenticated', true);
    await _box.put('phone', phone);
  }

  @override
  Future<String?> getVerifiedPhone() async {
    return _box.get('phone') as String? ?? _pendingPhone;
  }

  @override
  Future<void> completeSignup({
    required UserRole role,
    required String fullName,
    required String language,
  }) async {
    final phone = await getVerifiedPhone();

    if (phone == null) {
      throw Exception('Verified phone number not found');
    }

    if (fullName.trim().isEmpty) {
      throw Exception('Full name is required');
    }

    if (language != 'bn' && language != 'en') {
      throw Exception('Unsupported language');
    }

    await _box.put('role', role.value);

    await _box.put('fullName', fullName.trim());

    await _box.put('language', language);

    await _box.put('profileCompleted', true);
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final authenticated =
        _box.get('authenticated', defaultValue: false) as bool;

    final profileCompleted =
        _box.get('profileCompleted', defaultValue: false) as bool;

    if (!authenticated || !profileCompleted) {
      return null;
    }

    final phone = _box.get('phone') as String?;

    final fullName = _box.get('fullName') as String?;

    final language = _box.get('language') as String?;

    final roleValue = _box.get('role') as String?;

    if (phone == null ||
        fullName == null ||
        language == null ||
        roleValue == null) {
      return null;
    }

    final role = UserRole.values.firstWhere((item) => item.value == roleValue);

    return AppUser(
      id: 'mock-user-001',
      phone: phone,
      fullName: fullName,
      language: language,
      role: role,
    );
  }

  @override
  Future<void> signOut() async {
    await _box.clear();
    _pendingPhone = null;
  }
}
