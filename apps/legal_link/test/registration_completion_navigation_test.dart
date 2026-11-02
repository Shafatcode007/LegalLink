import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legal_link/core/app_mode.dart';
import 'package:legal_link/features/onboarding/domain/onboarding_providers.dart';
import 'package:legal_link/features/onboarding/presentation/screens/advocate_registration_screen.dart';
import 'package:legal_link/features/onboarding/presentation/widgets/credential_upload_field.dart';
import 'package:legal_link/l10n/app_localizations.dart';
import 'package:legal_link/shared/shared.dart';

import 'sprint2_widgets_test.dart'
    show TestPicker, TestUpload, TestRegistration, tapVisible;

void main() {
  for (final mode in AppMode.values) {
    for (final language in ['en', 'bn']) {
      testWidgets('$mode completion has an accessible $language exit to Home', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final registration = TestRegistration();
        final router = registrationRouter();
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appModeProvider.overrideWithValue(mode),
              credentialPickerProvider.overrideWithValue(TestPicker()),
              credentialUploadRepositoryProvider.overrideWithValue(
                TestUpload(),
              ),
              advocateRegistrationRepositoryProvider.overrideWithValue(
                registration,
              ),
            ],
            child: localizedRouter(router, language),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(AdvocateRegistrationScreen)),
        );
        await completeRegistration(tester, l10n, mode);
        expect(registration.registration!.isValid, true);
        final label = language == 'bn' ? 'হোমে ফিরুন' : 'Back to Home';
        final exit = find.widgetWithText(AppButton, label);
        expect(exit, findsOneWidget);
        expect(exit.hitTestable(), findsOneWidget);
        await tester.ensureVisible(exit);
        await tester.pumpAndSettle();
        expect(tester.getSize(exit).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
        await tapVisible(tester, exit);
        expect(find.text('Home destination'), findsOneWidget);
        expect(find.byType(AdvocateRegistrationScreen), findsNothing);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

GoRouter registrationRouter() => GoRouter(
  initialLocation: '/advocate-registration',
  routes: [
    GoRoute(
      path: '/advocate-registration',
      builder: (context, state) =>
          const AdvocateRegistrationScreen(userId: 'advocate'),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) =>
          const Scaffold(body: Text('Home destination')),
    ),
  ],
);

Widget localizedRouter(GoRouter router, String language) => MaterialApp.router(
  routerConfig: router,
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: true,
      textScaler: const TextScaler.linear(1.6),
    ),
    child: child!,
  ),
);

Future<void> completeRegistration(
  WidgetTester tester,
  AppLocalizations l10n,
  AppMode mode,
) async {
  final fields = find.byType(TextFormField);
  final values = [
    '1234567890',
    'BAR-42',
    'Dhaka Court',
    'Dhaka',
    '5',
    '1000',
    '5000',
    '4826',
    '4826',
  ];
  for (var i = 0; i < values.length; i++) {
    await tester.ensureVisible(fields.at(i));
    await tester.enterText(fields.at(i), values[i]);
  }
  await tapVisible(tester, find.text(l10n.specializationBail));
  final uploads = find.byType(CredentialUploadField);
  for (var i = 0; i < 2; i++) {
    await tapVisible(
      tester,
      find.descendant(of: uploads.at(i), matching: find.text(l10n.choosePhoto)),
    );
  }
  await tapVisible(
    tester,
    find.text(
      mode == AppMode.live
          ? l10n.registrationSubmitLive
          : l10n.submitRegistration,
    ),
  );
}
