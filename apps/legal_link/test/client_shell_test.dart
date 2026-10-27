import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/app/app.dart';
import 'package:legal_link/app/router.dart';
import 'package:legal_link/features/auth/domain/app_user.dart';
import 'package:legal_link/features/auth/domain/user_role.dart';
import 'package:legal_link/features/auth/presentation/providers/auth_controller.dart';
import 'package:legal_link/features/sos/presentation/screens/sos_screen.dart';
import 'package:legal_link/features/sos/presentation/widgets/hold_to_confirm_sos_button.dart';

import 'auth_flow_widget_test.dart' show WidgetFakeAuthRepository;

void main() {
  testWidgets('one persistent client SOS control survives route navigation', (
    tester,
  ) async {
    final repository = WidgetFakeAuthRepository()
      ..verifiedPhone = '+8801700000001'
      ..currentUser = const AppUser(
        id: 'client',
        phone: '+8801700000001',
        fullName: 'Client',
        language: 'en',
        role: UserRole.client,
      );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AinSohayApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HoldToConfirmSosButton), findsOneWidget);
    container.read(routerProvider).go('/sos');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HoldToConfirmSosButton), findsOneWidget);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToConfirmSosButton)),
    );
    await tester.pump(const Duration(milliseconds: 599));
    expect(find.byType(SosCaptureSheet), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SosCaptureSheet), findsOneWidget);
    expect(find.text('+8801700000001'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
