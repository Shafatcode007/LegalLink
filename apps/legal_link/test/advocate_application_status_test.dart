import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:legal_link/core/app_mode.dart';
import 'package:legal_link/features/home/presentation/widgets/advocate_registration_card.dart';
import 'package:legal_link/features/onboarding/domain/advocate_application.dart';
import 'package:legal_link/features/onboarding/domain/onboarding_providers.dart';
import 'package:legal_link/features/onboarding/presentation/screens/advocate_registration_screen.dart';
import 'package:legal_link/l10n/app_localizations.dart';

import 'live_registration_contract_test.dart' show application;
import 'sprint2_widgets_test.dart' show TestRegistration, tapVisible;

void main() {
  testWidgets('resubmission restores documents and returns to status on Home', (
    tester,
  ) async {
    final repo = TestRegistration()..savedApplication = saved();
    await mount(tester, repo);
    expect(find.text('Waiting for review'), findsOneWidget);
    await tapVisible(tester, find.text('Edit and resubmit'));
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(7));
    expect(
      tester.widget<TextFormField>(fields.at(0)).controller!.text,
      '1234567890',
    );
    expect(find.text('Previously uploaded photo'), findsNWidgets(2));
    expect(find.text('4-digit approval PIN'), findsNothing);
    await tester.ensureVisible(fields.at(1));
    await tester.enterText(fields.at(1), 'BAR-CORRECTED');
    await tapVisible(tester, find.text('Resubmit for verification'));
    expect(repo.submitCalls, 1);
    expect(repo.registration!.barCouncilNumber, 'BAR-CORRECTED');
    expect(repo.registration!.sanadReference, 'user-id/sanad.jpg');
    expect(repo.registration!.pin, isEmpty);
    expect(find.text('Application submitted'), findsOneWidget);
    expect(find.text('Back to Home').hitTestable(), findsOneWidget);
    await tapVisible(tester, find.text('Back to Home'));
    expect(find.text('Waiting for review'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('refresh replaces rejected feedback with verified state', (
    tester,
  ) async {
    final repo = TestRegistration()
      ..savedApplication = saved(
        verification: AdvocateVerification.rejected,
        reason: 'Please replace the unreadable Sanad photo.',
      );
    await mount(tester, repo);
    expect(find.text('Changes required'), findsOneWidget);
    expect(find.textContaining('unreadable Sanad'), findsOneWidget);
    expect(find.text('Edit and resubmit'), findsOneWidget);
    repo.savedApplication = saved(verification: AdvocateVerification.verified);
    await tapVisible(tester, find.text('Refresh'));
    expect(find.text('Verified advocate'), findsOneWidget);
    expect(find.text('Edit and resubmit'), findsNothing);
    expect(find.textContaining('unreadable Sanad'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pending status checks for approval without leaving Home', (
    tester,
  ) async {
    final repo = TestRegistration()..savedApplication = saved();
    await mount(tester, repo);
    repo.savedApplication = saved(verification: AdvocateVerification.verified);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('Verified advocate'), findsOneWidget);
    expect(find.text('Edit and resubmit'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('read failures and capped applications do not offer a new form', (
    tester,
  ) async {
    final repo = TestRegistration()..failRead = true;
    await mount(tester, repo);
    expect(find.textContaining('Could not load'), findsOneWidget);
    expect(find.text('Advocate Registration'), findsNothing);
    repo
      ..failRead = false
      ..savedApplication = saved(
        attempts: 3,
        verification: AdvocateVerification.rejected,
      );
    await tapVisible(tester, find.text('Refresh'));
    expect(find.textContaining('re-application limit'), findsOneWidget);
    expect(find.text('Edit and resubmit'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('approved direct registration link shows status and Home exit', (
    tester,
  ) async {
    final repo = TestRegistration()
      ..savedApplication = saved(verification: AdvocateVerification.verified);
    await mount(tester, repo, location: '/advocate-registration');
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Verified advocate'), findsOneWidget);
    expect(find.text('Back to Home').hitTestable(), findsOneWidget);
    await tapVisible(tester, find.text('Back to Home'));
    expect(find.byType(AdvocateRegistrationCard), findsOneWidget);
    expect(repo.submitCalls, 0);
    await tester.pumpWidget(const SizedBox());
  });
}

AdvocateApplication saved({
  AdvocateVerification verification = AdvocateVerification.pending,
  String? reason,
  int attempts = 0,
}) => AdvocateApplication(
  registration: application(),
  verification: verification,
  rejectionReason: reason,
  attempts: attempts,
);

Future<void> mount(
  WidgetTester tester,
  TestRegistration repo, {
  String location = '/home',
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(
          body: SingleChildScrollView(
            child: AdvocateRegistrationCard(userId: 'advocate'),
          ),
        ),
      ),
      GoRoute(
        path: '/advocate-registration',
        builder: (_, _) => const AdvocateRegistrationScreen(userId: 'advocate'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        advocateRegistrationRepositoryProvider.overrideWithValue(repo),
        appModeProvider.overrideWithValue(AppMode.live),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
