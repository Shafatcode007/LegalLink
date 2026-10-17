import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_link/features/admin/domain/entities/advocate_verification_item.dart';
import 'package:legal_link/features/admin/widgets/verification_status_chip.dart';
import 'package:legal_link/shared/shared.dart';

void main() {
  testWidgets('shared design-system widgets render supported states', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                AppButton.primary(
                  label: 'Primary',
                  icon: const Icon(Icons.add),
                  onPressed: () => taps++,
                ),
                AppButton.secondary(
                  label: 'Secondary',
                  onPressed: () => taps++,
                ),
                AppButton.ribbon(label: 'Ribbon', onPressed: () => taps++),
                AppButton.sos(label: 'SOS', onPressed: () => taps++),
                AppButton.primary(
                  label: 'Loading',
                  onPressed: () => taps++,
                  isLoading: true,
                ),
                const VerifiedBadge(),
                const VerifiedBadge(showEnglish: false, compact: true),
                const VerificationStatusChip(
                  status: VerificationStatus.pending,
                ),
                const VerificationStatusChip(
                  status: VerificationStatus.approved,
                ),
                const VerificationStatusChip(
                  status: VerificationStatus.rejected,
                ),
                const GavelBreathingRingLoader(message: 'Loading'),
                const LegalSkeletonLoader(width: 120, height: 20),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    for (final label in ['Primary', 'Secondary', 'Ribbon', 'SOS']) {
      final finder = find.text(label);

      await tester.ensureVisible(finder);
      await tester.pump();

      await tester.tap(finder);
      await tester.pump();
    }

    expect(taps, 4);

    expect(find.byType(VerifiedBadge), findsNWidgets(2));
    expect(find.byType(VerificationStatusChip), findsNWidgets(3));
    expect(find.byType(GavelBreathingRingLoader), findsOneWidget);
    expect(find.byType(LegalSkeletonLoader), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));

    // Dispose animation controllers before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
