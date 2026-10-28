import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_link/app/app.dart';
import 'package:legal_link/app/router.dart';
import 'package:legal_link/features/auth/domain/app_user.dart';
import 'package:legal_link/features/auth/domain/repositories/auth_repository.dart';
import 'package:legal_link/features/auth/domain/user_role.dart';
import 'package:legal_link/features/auth/presentation/providers/auth_controller.dart';
import 'package:legal_link/features/auth/presentation/screens/otp_screen.dart';
import 'package:legal_link/features/auth/presentation/screens/phone_screen.dart';
import 'package:legal_link/features/auth/presentation/screens/role_selection_screen.dart';
import 'package:legal_link/features/home/presentation/screens/home_screen.dart';
import 'package:legal_link/features/onboarding/presentation/screens/minimal_profile_screen.dart';
import 'package:legal_link/shared/shared.dart';

class WidgetFakeAuthRepository implements AuthRepository {
  String? verifiedPhone;
  AppUser? currentUser;

  @override
  Future<void> sendOtp(String phone) async {}

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
    final phone = verifiedPhone;

    if (phone == null) {
      throw Exception('Phone not verified');
    }

    currentUser = AppUser(
      id: 'widget-user',
      phone: phone,
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

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();

  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });
  testWidgets('new protected deep links wait for session restoration', (
    tester,
  ) async {
    final repository = WidgetFakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    router.go('/advocate-registration');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AinSohayApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PhoneScreen), findsOneWidget);
    container.read(routerProvider).go('/sos');
    await tester.pumpAndSettle();
    expect(find.byType(PhoneScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('client completes full auth onboarding and logout flow', (
    tester,
  ) async {
    final repository = WidgetFakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const AinSohayApp(),
      ),
    );

    await tester.pumpAndSettle();

    // -------------------------------------------------
    // PHONE
    // -------------------------------------------------

    expect(find.byType(PhoneScreen), findsOneWidget);

    final phoneField = find.byType(TextFormField).first;

    await tester.enterText(phoneField, '1712345678');

    await tester.pump();

    final sendOtpButton = find.byType(AppButton).first;

    await tapVisible(tester, sendOtpButton);

    // -------------------------------------------------
    // OTP
    // -------------------------------------------------

    expect(find.byType(OtpScreen), findsOneWidget);

    final otpField = find.byType(TextFormField).first;

    await tester.enterText(otpField, '123456');

    await tester.pump();

    final verifyButton = find.byType(AppButton).first;

    await tapVisible(tester, verifyButton);

    // -------------------------------------------------
    // ROLE
    // -------------------------------------------------

    expect(find.byType(RoleSelectionScreen), findsOneWidget);

    final clientRole = find.text(
      '\u0995\u09cd\u09b2\u09be\u09af\u09bc\u09c7\u09a8\u09cd\u099f',
    );

    await tester.ensureVisible(clientRole);

    await tester.pumpAndSettle();

    await tester.tap(clientRole);

    await tester.pump();

    final continueButton = find.byType(AppButton).first;

    await tapVisible(tester, continueButton);

    // -------------------------------------------------
    // PROFILE
    // -------------------------------------------------

    expect(find.byType(MinimalProfileScreen), findsOneWidget);

    final nameField = find.byType(TextFormField).first;

    await tester.enterText(nameField, 'Akib Hassan');

    await tester.pump();

    final saveButton = find.byType(AppButton).first;

    await tapVisible(tester, saveButton);

    // -------------------------------------------------
    // HOME
    // -------------------------------------------------

    expect(find.byType(HomeScreen), findsOneWidget);

    expect(find.text('Akib Hassan'), findsOneWidget);

    expect(find.text('+8801712345678'), findsOneWidget);

    expect(repository.currentUser, isNotNull);

    expect(repository.currentUser!.role, UserRole.client);

    expect(repository.currentUser!.language, 'bn');

    // -------------------------------------------------
    // LOGOUT
    // -------------------------------------------------

    final logoutButton = find.byType(AppButton).first;

    await tapVisible(tester, logoutButton);

    expect(find.byType(PhoneScreen), findsOneWidget);

    expect(repository.currentUser, isNull);
  });
}
