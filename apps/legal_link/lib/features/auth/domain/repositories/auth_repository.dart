import '../app_user.dart';
import '../user_role.dart';

abstract interface class AuthRepository {
  Future<void> sendOtp(String phone);

  Future<void> verifyOtp({required String phone, required String otp});

  Future<String?> getVerifiedPhone();

  Future<void> completeSignup({
    required UserRole role,
    required String fullName,
    required String language,
  });

  Future<AppUser?> getCurrentUser();

  Future<void> signOut();
}
