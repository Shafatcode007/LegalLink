import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/user_role.dart';

class AuthState {
  const AuthState({
    this.phone,
    this.role,
    this.user,
    this.language = 'bn',
    this.otpVerified = false,
    this.roleConfirmed = false,
    this.loading = false,
    this.initializing = true,
    this.error,
  });

  final String? phone;
  final UserRole? role;
  final AppUser? user;

  /// Current UI language.
  ///
  /// Supported values:
  /// - bn = Bangla
  /// - en = English
  final String language;

  final bool otpVerified;
  final bool roleConfirmed;
  final bool loading;
  final bool initializing;

  final String? error;

  bool get isSignedIn => user != null;

  AuthState copyWith({
    String? phone,
    UserRole? role,
    AppUser? user,
    String? language,
    bool? otpVerified,
    bool? roleConfirmed,
    bool? loading,
    bool? initializing,
    String? error,
    bool clearError = false,
    bool clearUser = false,
    bool clearRole = false,
    bool clearPhone = false,
  }) {
    return AuthState(
      phone: clearPhone ? null : phone ?? this.phone,
      role: clearRole ? null : role ?? this.role,
      user: clearUser ? null : user ?? this.user,
      language: language ?? this.language,
      otpVerified: otpVerified ?? this.otpVerified,
      roleConfirmed: roleConfirmed ?? this.roleConfirmed,
      loading: loading ?? this.loading,
      initializing: initializing ?? this.initializing,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw StateError('AuthRepository must be overridden in app/di.dart');
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.read(authRepositoryProvider);

    Future.microtask(_restoreSession);

    return const AuthState();
  }

  Future<void> _restoreSession() async {
    final phone = await _repository.getVerifiedPhone();
    final user = await _repository.getCurrentUser();

    state = state.copyWith(
      phone: phone,
      user: user,
      role: user?.role,
      language: user?.language ?? state.language,
      otpVerified: phone != null,
      roleConfirmed: user != null,
      initializing: false,
      clearError: true,
    );
  }

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      await _repository.sendOtp(phone);

      state = state.copyWith(
        phone: phone,
        loading: false,
        otpVerified: false,
        roleConfirmed: false,
        clearRole: true,
        clearUser: true,
      );

      return true;
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());

      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    final phone = state.phone;

    if (phone == null) {
      state = state.copyWith(error: 'Phone number not found');

      return false;
    }

    state = state.copyWith(loading: true, clearError: true);

    try {
      await _repository.verifyOtp(phone: phone, otp: otp);

      state = state.copyWith(
        otpVerified: true,
        roleConfirmed: false,
        loading: false,
        clearRole: true,
        clearUser: true,
      );

      return true;
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Invalid OTP');

      return false;
    }
  }

  void selectRole(UserRole role) {
    state = state.copyWith(role: role, roleConfirmed: false, clearError: true);
  }

  void confirmRole() {
    if (state.role == null) {
      state = state.copyWith(error: 'Please select a role');

      return;
    }

    state = state.copyWith(roleConfirmed: true, clearError: true);
  }

  /// Changes the current UI language.
  ///
  /// This immediately updates the app locale through AinSohayApp.
  void setLanguage(String language) {
    if (language != 'bn' && language != 'en') {
      return;
    }

    state = state.copyWith(language: language, clearError: true);
  }

  Future<bool> completeProfile({
    required String fullName,
    required String language,
  }) async {
    final role = state.role;

    if (role == null) {
      state = state.copyWith(error: 'Please select a role');

      return false;
    }

    if (!state.roleConfirmed) {
      state = state.copyWith(error: 'Please confirm your role');

      return false;
    }

    state = state.copyWith(loading: true, clearError: true);

    try {
      await _repository.completeSignup(
        role: role,
        fullName: fullName,
        language: language,
      );

      final user = await _repository.getCurrentUser();

      if (user == null) {
        state = state.copyWith(
          loading: false,
          error: 'Unable to complete profile',
        );

        return false;
      }

      state = state.copyWith(
        user: user,
        phone: user.phone,
        role: user.role,
        language: user.language,
        otpVerified: true,
        roleConfirmed: true,
        loading: false,
        clearError: true,
      );

      return true;
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());

      return false;
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();

    state = const AuthState(initializing: false);
  }
}
