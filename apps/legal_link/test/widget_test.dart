import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/features/admin/admin.dart';
import 'package:legal_link/main.dart';

void main() {
  testWidgets('Admin Verification Queue loads correctly smoke test',
      (WidgetTester tester) async {
    // Build LegalLinkApp and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: LegalLinkApp(),
      ),
    );

    // Verify that the queue screen header is present
    expect(find.text('আইনজীবী যাচাইকরণ কিউ'), findsOneWidget);
    expect(find.byType(AdminVerificationQueueScreen), findsOneWidget);
  });
}
