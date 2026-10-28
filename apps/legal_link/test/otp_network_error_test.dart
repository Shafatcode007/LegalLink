import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/features/auth/presentation/providers/auth_controller.dart';
import 'package:legal_link/features/auth/presentation/screens/otp_screen.dart';
import 'package:legal_link/l10n/app_localizations.dart';

import 'auth_flow_widget_test.dart' show WidgetFakeAuthRepository;

class OfflineOtpRepository extends WidgetFakeAuthRepository {
  @override
  Future<void> verifyOtp({required String phone, required String otp}) async {
    throw StateError('offline');
  }
}

void main() {
  testWidgets('OTP transport failures are not reported as incorrect codes', (
    tester,
  ) async {
    final repository = OfflineOtpRepository()..verifiedPhone = '+8801700000001';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OtpScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('The verification code is incorrect'), findsNothing);
  });
}
