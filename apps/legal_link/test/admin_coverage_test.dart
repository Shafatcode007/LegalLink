import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_link/features/admin/admin.dart';
import 'package:legal_link/shared/shared.dart';

void main() {
  test('admin repository and domain operations work', () async {
    final repository = VerificationRepositoryImpl();

    final original = await repository.getAll();

    expect(original.length, 4);

    final first = original.first;

    expect(first.status.isPending, isTrue);
    expect(VerificationStatus.pending.isPending, isTrue);
    expect(VerificationStatus.approved.isApproved, isTrue);
    expect(VerificationStatus.rejected.isRejected, isTrue);

    expect(VerificationStatus.pending.label, isNotEmpty);
    expect(VerificationStatus.approved.label, isNotEmpty);
    expect(VerificationStatus.rejected.label, isNotEmpty);

    final copied = first.copyWith(
      fullName: 'Updated Advocate',
      status: VerificationStatus.approved,
      rejectionReason: 'none',
    );

    expect(copied.fullName, 'Updated Advocate');
    expect(copied.status, VerificationStatus.approved);

    expect(repository.getById('adv-001'), isNotNull);
    expect(repository.getById('missing-id'), isNull);

    await repository.approve('adv-001');

    expect(repository.getById('adv-001')!.status, VerificationStatus.approved);

    await repository.reject('adv-002', reason: 'test reason');

    final rejected = repository.getById('adv-002')!;

    expect(rejected.status, VerificationStatus.rejected);

    expect(rejected.rejectionReason, 'test reason');

    // Missing IDs should safely do nothing.
    await repository.approve('missing-id');
    await repository.reject('missing-id');

    await repository.refresh();
  });

  test('admin notifier supports loading filtering and decisions', () async {
    final container = ProviderContainer();

    addTearDown(container.dispose);

    final notifier = container.read(adminVerificationProvider.notifier);

    await notifier.load();

    var state = container.read(adminVerificationProvider);

    expect(state.items.length, 4);
    expect(state.pendingCount, 3);
    expect(state.approvedCount, 1);
    expect(state.rejectedCount, 0);

    notifier.setFilter(VerificationStatus.pending);

    state = container.read(adminVerificationProvider);

    expect(
      state.filteredItems.every(
        (item) => item.status == VerificationStatus.pending,
      ),
      isTrue,
    );

    notifier.setFilter(null);

    expect(container.read(adminVerificationProvider).filteredItems.length, 4);

    expect(notifier.getById('adv-001'), isNotNull);
    expect(notifier.getById('missing-id'), isNull);

    await notifier.approve('adv-001');

    expect(notifier.getById('adv-001')!.status, VerificationStatus.approved);

    await notifier.reject('adv-002', reason: 'test reject');

    expect(notifier.getById('adv-002')!.status, VerificationStatus.rejected);

    await notifier.refresh();

    expect(container.read(adminVerificationProvider).isLoading, isFalse);
  });

  testWidgets('admin profile renders pending approved and missing states', (
    tester,
  ) async {
    Future<void> showProfile(String advocateId) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          child: MaterialApp(
            home: AdvocateProfileViewScreen(advocateId: advocateId),
          ),
        ),
      );

      await tester.pump();
    }

    // Pending advocate.
    await showProfile('adv-001');

    expect(find.byType(AdvocateProfileViewScreen), findsOneWidget);

    expect(find.byType(VerificationStatusChip), findsOneWidget);

    expect(find.byType(AppButton), findsNWidgets(2));

    // Approved advocate.
    await showProfile('adv-004');

    expect(find.byType(VerifiedBadge), findsOneWidget);

    // Unknown advocate.
    await showProfile('missing-id');

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('admin queue renders loaded and filtered states', (tester) async {
    final container = ProviderContainer();

    addTearDown(container.dispose);

    final notifier = container.read(adminVerificationProvider.notifier);

    await notifier.load();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AdminVerificationQueueScreen()),
      ),
    );

    await tester.pump();

    expect(find.byType(AdminVerificationQueueScreen), findsOneWidget);

    expect(find.byType(VerificationStatusChip), findsWidgets);

    notifier.setFilter(VerificationStatus.approved);
    await tester.pump();

    expect(container.read(adminVerificationProvider).filteredItems.length, 1);

    notifier.setFilter(VerificationStatus.rejected);
    await tester.pump();

    expect(container.read(adminVerificationProvider).filteredItems, isEmpty);

    expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);

    notifier.setFilter(null);
    await tester.pump();

    expect(container.read(adminVerificationProvider).filteredItems.length, 4);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
