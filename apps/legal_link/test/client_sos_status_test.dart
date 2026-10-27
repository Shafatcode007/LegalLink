import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/features/sos/domain/sos_draft.dart';
import 'package:legal_link/features/sos/domain/sos_providers.dart';
import 'package:legal_link/features/sos/presentation/widgets/client_sos_status_panel.dart';
import 'package:legal_link/features/sos/presentation/screens/sos_screen.dart';
import 'package:legal_link/core/app_mode.dart';
import 'package:legal_link/l10n/app_localizations.dart';

class StatusRepository extends SosRepository {
  final updates = StreamController<ClientSosRequest>.broadcast();
  @override
  Future<ClientSosRequest?> currentOpen() async => state(ClientSosStatus.open);
  @override
  Stream<ClientSosRequest> watch(String id, String district) => updates.stream;
  @override
  Future<ClientSosRequest> submit(SosDraft draft) => throw UnimplementedError();
}

ClientSosRequest state(ClientSosStatus status) =>
    ClientSosRequest(id: 'request', district: 'Dhaka', status: status);

void main() {
  testWidgets('a declined request is distinguished from expiry', (
    tester,
  ) async {
    final repository = StatusRepository();
    addTearDown(repository.updates.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sosRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ClientSosStatusPanel(
              request: state(ClientSosStatus.declined),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SOS declined'), findsOneWidget);
    expect(find.text('SOS expired'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'reopening SOS restores the existing server request before showing a new form',
    (tester) async {
      final repository = StatusRepository();
      addTearDown(repository.updates.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sosRepositoryProvider.overrideWithValue(repository),
            appModeProvider.overrideWithValue(AppMode.live),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SosCaptureSheet(contactPhone: '+8801700000001'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SOS request sent'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'server acceptance replaces waiting state and keeps errors explicit',
    (tester) async {
      final repository = StatusRepository();
      addTearDown(repository.updates.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sosRepositoryProvider.overrideWithValue(repository)],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ClientSosStatusPanel(request: state(ClientSosStatus.open)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SOS request sent'), findsOneWidget);
      expect(find.text('Cancel SOS'), findsOneWidget);
      repository.updates.add(state(ClientSosStatus.accepted));
      await tester.pumpAndSettle();
      expect(find.text('An advocate accepted your SOS'), findsOneWidget);
      expect(find.text('Cancel SOS'), findsNothing);
      repository.updates.addError(ClientSosFailure.unavailable);
      await tester.pumpAndSettle();
      expect(find.text('An advocate accepted your SOS'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
