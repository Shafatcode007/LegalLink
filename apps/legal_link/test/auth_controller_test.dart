import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_link/features/auth/domain/app_user.dart';
import 'package:legal_link/features/auth/domain/repositories/auth_repository.dart';
import 'package:legal_link/features/auth/domain/user_role.dart';
import 'package:legal_link/features/auth/presentation/providers/auth_controller.dart';

class FakeAuthRepository implements AuthRepository {
  String? verifiedPhone;
  AppUser? currentUser;

  @override
  Future<void> sendOtp(String phone) async {
    if (phone.isEmpty) {
      throw Exception('Phone required');
    }

    verifiedPhone = phone;
  }

  @override
  Future<void> verifyOtp({required String phone, required String otp}) async {
    if (otp != '123456') {
      throw Exception('Invalid OTP');
    }

    verifiedPhone = phone;
  }

  @override
  Future<String?> getVerifiedPhone() async {
    return verifiedPhone;
  }

  @override
  Future<void> completeSignup({
    required UserRole role,
    required String fullName,
    required String language,
  }) async {
    if (verifiedPhone == null) {
      throw Exception('Phone not verified');
    }

    if (fullName.trim().isEmpty) {
      throw Exception('Name required');
    }

    currentUser = AppUser(
      id: 'test-user-1',
      phone: verifiedPhone!,
      fullName: fullName,
      language: language,
      role: role,
    );
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    return currentUser;
  }

  @override
  Future<void> signOut() async {
    verifiedPhone = null;
    currentUser = null;
  }
}

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeAuthRepository();

    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('initial auth state restores as signed out', () async {
    container.read(authControllerProvider);

    await Future<void>.delayed(Duration.zero);

    final state = container.read(authControllerProvider);

    expect(state.initializing, false);
    expect(state.isSignedIn, false);
    expect(state.user, isNull);
  });

  test('sendOtp stores phone in auth state', () async {
    final controller = container.read(authControllerProvider.notifier);

    await Future<void>.delayed(Duration.zero);

    final result = await controller.sendOtp('+8801712345678');

    final state = container.read(authControllerProvider);

    expect(result, true);
    expect(state.phone, '+8801712345678');
    expect(state.otpVerified, false);
    expect(state.loading, false);
  });

  test('valid OTP marks phone as verified', () async {
    final controller = container.read(authControllerProvider.notifier);

    await Future<void>.delayed(Duration.zero);

    await controller.sendOtp('+8801712345678');

    final result = await controller.verifyOtp('123456');

    final state = container.read(authControllerProvider);

    expect(result, true);
    expect(state.otpVerified, true);
    expect(state.loading, false);
  });

  test('invalid OTP returns false and sets error', () async {
    final controller = container.read(authControllerProvider.notifier);

    await Future<void>.delayed(Duration.zero);

    await controller.sendOtp('+8801712345678');

    final result = await controller.verifyOtp('000000');

    final state = container.read(authControllerProvider);

    expect(result, false);
    expect(state.otpVerified, false);
    expect(state.error, 'Invalid OTP');
  });

  test('verifyOtp fails when phone is missing', () async {
    final controller = container.read(authControllerProvider.notifier);

    await Future<void>.delayed(Duration.zero);

    final result = await controller.verifyOtp('123456');

    final state = container.read(authControllerProvider);

    expect(result, false);
    expect(state.error, 'Phone number not found');
  });

  test('selectRole stores client role', () async {
    final controller = container.read(authControllerProvider.notifier);

    await Future<void>.delayed(Duration.zero);

    controller.selectRole(UserRole.client);

    final state = container.read(authControllerProvider);

    expect(state.role, UserRole.client);
    expect(state.roleConfirmed, false);
  });

  test('confirmRole confirms selected role', () async {
    final controller = container.read(authControllerProvider.notifier);

    await Future<void>.delayed(Duration.zero);

    controller.selectRole(UserRole.advocate);
    controller.confirmRole();

    final state = container.read(authControllerProvider);

    expect(state.role, UserRole.advocate);
    expect(state.roleConfirmed, true);
  });

  test('confirmRole fails when no role selected', () async {
    final controller = container.read(authControllerProvider.notifier);

    await Future<void>.delayed(Duration.zero);

    controller.confirmRole();

    final state = container.read(authControllerProvider);

    expect(state.roleConfirmed, false);
    expect(state.error, 'Please select a role');
  });

  test('completeProfile creates signed in client', () async {
    final controller = container.read(authControllerProvider.notifier);

    await Future<void>.delayed(Duration.zero);

    await controller.sendOtp('+8801712345678');
    await controller.verifyOtp('123456');

    controller.selectRole(UserRole.client);
    controller.confirmRole();

    final result = await controller.completeProfile(
      fullName: 'Akib Hassan',
      language: 'bn',
    );

    final state = container.read(authControllerProvider);

    expect(result, true);
    expect(state.isSignedIn, true);
    expect(state.user, isNotNull);
    expect(state.user!.fullName, 'Akib Hassan');
    expect(state.user!.phone, '+8801712345678');
    expect(state.user!.language, 'bn');
    expect(state.user!.role, UserRole.client);
  });

  test('completeProfile fails without role', () async {
    final controller = container.read(authControllerProvider.notifier);

    await Future<void>.delayed(Duration.zero);

    final result = await controller.completeProfile(
      fullName: 'Akib Hassan',
      language: 'bn',
    );

    expect(result, false);

    final state = container.read(authControllerProvider);

    expect(state.error, 'Please select a role');
  });

  test('completeProfile fails when role is not confirmed', () async {
    final controller = container.read(authControllerProvider.notifier);

    await Future<void>.delayed(Duration.zero);

    controller.selectRole(UserRole.client);

    final result = await controller.completeProfile(
      fullName: 'Akib Hassan',
      language: 'bn',
    );

    expect(result, false);

    final state = container.read(authControllerProvider);

    expect(state.error, 'Please confirm your role');
  });

  test('signOut clears authenticated user', () async {
    final controller = container.read(authControllerProvider.notifier);

    await Future<void>.delayed(Duration.zero);

    await controller.sendOtp('+8801712345678');
    await controller.verifyOtp('123456');

    controller.selectRole(UserRole.client);
    controller.confirmRole();

    await controller.completeProfile(fullName: 'Akib Hassan', language: 'bn');

    expect(container.read(authControllerProvider).isSignedIn, true);

    await controller.signOut();

    final state = container.read(authControllerProvider);

    expect(state.isSignedIn, false);
    expect(state.user, isNull);
    expect(state.phone, isNull);
    expect(state.role, isNull);
  });
}
