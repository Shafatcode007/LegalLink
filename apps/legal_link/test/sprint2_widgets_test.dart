import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/features/onboarding/domain/advocate_registration.dart';
import 'package:legal_link/features/onboarding/domain/credential_upload.dart';
import 'package:legal_link/features/onboarding/domain/onboarding_providers.dart';
import 'package:legal_link/features/onboarding/presentation/screens/advocate_registration_screen.dart';
import 'package:legal_link/features/onboarding/presentation/widgets/credential_upload_field.dart';
import 'package:legal_link/features/sos/domain/sos_draft.dart';
import 'package:legal_link/features/sos/domain/sos_providers.dart';
import 'package:legal_link/features/sos/presentation/screens/sos_screen.dart';
import 'package:legal_link/l10n/app_localizations.dart';
import 'package:legal_link/shared/shared.dart';

class TestPicker implements CredentialPicker {
  CredentialFile? file = CredentialFile(
    name: 'credential.jpg',
    bytes: Uint8List.fromList([255, 216, 255]),
  );
  @override
  Future<CredentialFile?> pick() async => file;
}

class TestUpload implements CredentialUploadRepository {
  int calls = 0;
  bool fail = false;
  @override
  Future<String> upload({
    required String userId,
    required CredentialKind kind,
    required CredentialFile file,
    required void Function(double progress) onProgress,
  }) async {
    calls++;
    onProgress(0.5);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (fail) throw UploadFailure.unavailable;
    return 'demo/$userId/${kind.name}';
  }
}

class TestRegistration implements AdvocateRegistrationRepository {
  AdvocateRegistration? registration;
  @override
  Future<void> submit(String userId, AdvocateRegistration registration) async {
    this.registration = registration;
  }
}

class TestSos extends SosRepository {
  int calls = 0;
  SosDraft? draft;
  @override
  Future<ClientSosRequest> submit(SosDraft draft) async {
    calls++;
    if (calls == 1) throw StateError('connection failed');
    this.draft = draft;
    return ClientSosRequest(
      id: 'demo',
      district: draft.districtCourt,
      status: ClientSosStatus.open,
      isDemo: true,
    );
  }
}

Widget localized(Widget child, {String language = 'en', double scale = 1}) =>
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: child,
    );

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'registration collects PIN, district, experience and availability',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: localized(
            const AdvocateRegistrationScreen(userId: 'advocate'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4-digit approval PIN'), findsOneWidget);
      expect(find.text('Confirm approval PIN'), findsOneWidget);
      expect(find.text('Districts served'), findsOneWidget);
      expect(find.text('Years of practice'), findsOneWidget);
      expect(find.text('Available for SOS requests'), findsOneWidget);
    },
  );
  testWidgets(
    'upload failure retains file for retry; picker cancel retains success',
    (tester) async {
      final picker = TestPicker();
      final upload = TestUpload()..fail = true;
      String? reference;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            credentialPickerProvider.overrideWithValue(picker),
            credentialUploadRepositoryProvider.overrideWithValue(upload),
          ],
          child: localized(
            Scaffold(
              body: CredentialUploadField(
                userId: 'advocate',
                kind: CredentialKind.sanad,
                label: 'Sanad',
                onChanged: (value, busy) => reference = value,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Choose photo'));
      expect(
        find.text('Could not prepare the photo. Retry or choose another file.'),
        findsOneWidget,
      );
      expect(reference, isNull);
      upload.fail = false;
      await tapVisible(tester, find.text('Retry'));
      expect(reference, 'demo/advocate/sanad');
      picker.file = null;
      await tapVisible(tester, find.text('Replace photo'));
      expect(reference, 'demo/advocate/sanad');
      expect(upload.calls, 2);
    },
  );

  testWidgets(
    'registration validates and submits all credential and practice fields',
    (tester) async {
      final registration = TestRegistration();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            credentialPickerProvider.overrideWithValue(TestPicker()),
            credentialUploadRepositoryProvider.overrideWithValue(TestUpload()),
            advocateRegistrationRepositoryProvider.overrideWithValue(
              registration,
            ),
          ],
          child: localized(
            const AdvocateRegistrationScreen(userId: 'advocate'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Complete registration demo'));
      expect(registration.registration, isNull);
      final fields = find.byType(TextFormField);
      for (final entry in {
        0: '1234567890',
        1: 'BAR-2026-42',
        2: 'Dhaka District Court, High Court',
        3: 'Dhaka',
        4: '5',
        5: '1000',
        6: '5000',
        7: '4826',
        8: '4826',
      }.entries) {
        await tester.ensureVisible(fields.at(entry.key));
        await tester.enterText(fields.at(entry.key), entry.value);
      }
      await tapVisible(tester, find.text('Bail'));
      final uploads = find.byType(CredentialUploadField);
      for (var index = 0; index < 2; index++) {
        await tapVisible(
          tester,
          find.descendant(
            of: uploads.at(index),
            matching: find.text('Choose photo'),
          ),
        );
      }
      await tapVisible(tester, find.text('Complete registration demo'));
      expect(registration.registration!.isValid, true);
      expect(registration.registration!.courts, [
        'Dhaka District Court',
        'High Court',
      ]);
      expect(registration.registration!.feeMax, 5000);
      expect(find.text('Registration demo complete'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SOS error preserves capture fields and retry completes without a live claim',
    (tester) async {
      final repository = TestSos();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sosRepositoryProvider.overrideWithValue(repository)],
          child: localized(
            const Scaffold(
              body: SosCaptureSheet(contactPhone: '+8801712345678'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Complete SOS demo'));
      expect(repository.calls, 0);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Person Name');
      await tester.enterText(fields.at(1), 'Dhanmondi');
      await tester.enterText(fields.at(2), 'Dhaka');
      await tapVisible(tester, find.text('Complete SOS demo'));
      expect(
        find.text(
          'Could not complete the demo. Your details are still here; please retry.',
        ),
        findsOneWidget,
      );
      expect(find.text('Person Name'), findsOneWidget);
      await tapVisible(tester, find.text('Retry demo'));
      expect(repository.draft!.contactPhone, '+8801712345678');
      expect(find.text('SOS demo complete — no alert sent'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final language in ['en', 'bn']) {
    testWidgets(
      'narrow $language screens support enlarged text and accessible targets',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: localized(
              const AdvocateRegistrationScreen(userId: 'advocate'),
              language: language,
              scale: 1.6,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(AppButton).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          ProviderScope(
            child: localized(
              const SosScreen(contactPhone: '+8801712345678'),
              language: language,
              scale: 1.6,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
