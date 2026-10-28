import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:ui' show SemanticsAction, SemanticsActionEvent;

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/features/sos/presentation/widgets/hold_to_confirm_sos_button.dart';
import 'package:legal_link/l10n/app_localizations.dart';

Widget host(VoidCallback onConfirmed, {bool reducedMotion = true}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reducedMotion),
          child: Scaffold(
            body: Center(
              child: HoldToConfirmSosButton(onConfirmed: onConfirmed),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('backgrounding the app cancels a pending hold', (tester) async {
    var confirmations = 0;
    await tester.pumpWidget(host(() => confirmations++));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToConfirmSosButton)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 600));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(confirmations, 0);
    await gesture.up();
  });
  testWidgets('release before 600 ms cancels; a fresh hold confirms once', (
    tester,
  ) async {
    var confirmations = 0;
    await tester.pumpWidget(host(() => confirmations++));
    await tester.pumpAndSettle();
    final target = find.byType(HoldToConfirmSosButton);
    var gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 599));
    expect(confirmations, 0);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(confirmations, 0);
    gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(confirmations, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(confirmations, 1);
    await gesture.up();
  });

  testWidgets('drag outside and pointer cancellation cancel the hold', (
    tester,
  ) async {
    var confirmations = 0;
    await tester.pumpWidget(host(() => confirmations++));
    await tester.pumpAndSettle();
    final target = find.byType(HoldToConfirmSosButton);
    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveBy(const Offset(250, 0));
    await tester.pump(const Duration(milliseconds: 600));
    expect(confirmations, 0);
    await gesture.up();
    final cancelled = await tester.startGesture(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 300));
    await cancelled.cancel();
    await tester.pump(const Duration(milliseconds: 600));
    expect(confirmations, 0);
  });

  testWidgets('keyboard holds also require 600 ms with reduced motion', (
    tester,
  ) async {
    var confirmations = 0;
    await tester.pumpWidget(host(() => confirmations++));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 599));
    expect(confirmations, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(confirmations, 1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
  });

  testWidgets('screen reader activation requires explicit confirmation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var confirmations = 0;
    await tester.pumpWidget(host(() => confirmations++));
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.bySemanticsLabel('Emergency SOS'));
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        type: SemanticsAction.tap,
        viewId: tester.view.viewId,
        nodeId: node.id,
      ),
    );
    await tester.pumpAndSettle();
    expect(confirmations, 0);
    expect(find.text('Start an SOS request?'), findsOneWidget);
    await tester.tap(find.text('Continue to details'));
    await tester.pumpAndSettle();
    expect(confirmations, 1);
    semantics.dispose();
  });
}
