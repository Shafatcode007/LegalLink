import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/app/di.dart';
import 'package:legal_link/features/admin/admin.dart';

void main() {
  group('MockAdminVerificationRepository (Data Layer)', () {
    late MockAdminVerificationRepository repository;

    setUp(() {
      repository = MockAdminVerificationRepository();
    });

    test('getCachedAdvocates returns initial 4 mock items', () {
      final cached = repository.getCachedAdvocates();
      expect(cached.length, 4);
      expect(cached.any((a) => a.id == 'adv-001'), isTrue);
    });

    test('getAdvocates returns list of advocates asynchronously', () async {
      final items = await repository.getAdvocates();
      expect(items.length, 4);
    });

    test(
      'getById returns advocate for matching id and null for non-existent',
      () async {
        final item = await repository.getById('adv-001');
        expect(item, isNotNull);
        expect(item!.barCouncilNo, 'BC-DH-2014-8841');

        final notFound = await repository.getById('non-existent-id');
        expect(notFound, isNull);
      },
    );

    test('updateStatus updates advocate status to approved', () async {
      await repository.updateStatus('adv-001', VerificationStatus.approved);
      final item = await repository.getById('adv-001');
      expect(item!.status, VerificationStatus.approved);
      expect(item.status.isApproved, isTrue);
    });

    test(
      'updateStatus updates advocate status to rejected with reason',
      () async {
        await repository.updateStatus(
          'adv-001',
          VerificationStatus.rejected,
          reason: 'সনদপত্র মেয়াদোত্তীর্ণ',
        );
        final item = await repository.getById('adv-001');
        expect(item!.status, VerificationStatus.rejected);
        expect(item.status.isRejected, isTrue);
        expect(item.rejectionReason, 'সনদপত্র মেয়াদোত্তীর্ণ');
      },
    );

    test(
      'getDocumentSignedUrl returns 15-min secure signed preview URL',
      () async {
        final signedUrl = await repository.getDocumentSignedUrl(
          'sanad/BC-DH-2014-8841.pdf',
        );
        expect(signedUrl, isNotNull);
        expect(signedUrl, contains('exp_15m_signed_sec_preview'));
      },
    );
  });

  group('SupabaseAdminVerificationRepository (Real Backend Wired)', () {
    late SupabaseAdminVerificationRepository repository;

    setUp(() {
      repository = SupabaseAdminVerificationRepository();
    });

    test(
      'getAdvocates resolves items and populates 15-minute signed URLs',
      () async {
        final items = await repository.getAdvocates();
        expect(items.isNotEmpty, isTrue);
        final first = items.first;
        expect(first.sanadSignedUrl, isNotNull);
        expect(first.isSignedUrlValid, isTrue);
        expect(first.signedUrlExpiresAt, isNotNull);
      },
    );

    test(
      'getDocumentSignedUrl generates secure temporary signed URL',
      () async {
        final signedUrl = await repository.getDocumentSignedUrl(
          'sanad/BC-DH-2014-8841.pdf',
        );
        expect(signedUrl, isNotNull);
        expect(signedUrl, contains('token=exp_15m'));
      },
    );

    test('updateStatus mutates status and persists rejection reason', () async {
      await repository.updateStatus(
        'adv-002',
        VerificationStatus.rejected,
        reason: 'সনদ অস্পষ্ট',
      );
      final item = await repository.getById('adv-002');
      expect(item?.status, VerificationStatus.rejected);
      expect(item?.rejectionReason, 'সনদ অস্পষ্ট');
    });
  });

  group('AdminVerificationNotifier (Presentation Layer)', () {
    late ProviderContainer container;
    late MockAdminVerificationRepository repository;

    setUp(() {
      repository = MockAdminVerificationRepository();
      container = ProviderContainer(
        overrides: createDiOverrides(adminVerificationRepository: repository),
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state contains cached advocates', () {
      final state = container.read(adminVerificationProvider);
      expect(state.items.length, 4);
      expect(state.isLoading, isFalse);
      expect(state.pendingCount, 3);
      expect(state.approvedCount, 1);
      expect(state.rejectedCount, 0);
    });

    test('filtering by status correctly filters items', () {
      final notifier = container.read(adminVerificationProvider.notifier);

      notifier.setFilter(VerificationStatus.pending);
      var state = container.read(adminVerificationProvider);
      expect(state.filter, VerificationStatus.pending);
      expect(state.filteredItems.length, 3);
      expect(state.filteredItems.every((i) => i.status.isPending), isTrue);

      notifier.setFilter(VerificationStatus.approved);
      state = container.read(adminVerificationProvider);
      expect(state.filteredItems.length, 1);
      expect(state.filteredItems.first.status.isApproved, isTrue);

      notifier.setFilter(null);
      state = container.read(adminVerificationProvider);
      expect(state.filter, isNull);
      expect(state.filteredItems.length, 4);
    });

    test('approve transitions status to approved and updates counts', () async {
      final notifier = container.read(adminVerificationProvider.notifier);
      await notifier.approve('adv-001');

      final state = container.read(adminVerificationProvider);
      final item = notifier.getById('adv-001');
      expect(item?.status, VerificationStatus.approved);
      expect(state.pendingCount, 2);
      expect(state.approvedCount, 2);
      expect(state.isLoading, isFalse);
    });

    test('reject transitions status to rejected and updates counts', () async {
      final notifier = container.read(adminVerificationProvider.notifier);
      await notifier.reject('adv-002', reason: 'অসম্পূর্ণ নথি');

      final state = container.read(adminVerificationProvider);
      final item = notifier.getById('adv-002');
      expect(item?.status, VerificationStatus.rejected);
      expect(item?.rejectionReason, 'অসম্পূর্ণ নথি');
      expect(state.pendingCount, 2);
      expect(state.rejectedCount, 1);
      expect(state.isLoading, isFalse);
    });

    test('getSignedUrlFor generates active signed URL on entity', () async {
      final notifier = container.read(adminVerificationProvider.notifier);
      final signedUrl = await notifier.getSignedUrlFor('adv-001');

      expect(signedUrl, isNotNull);
      final item = notifier.getById('adv-001');
      expect(item?.sanadSignedUrl, signedUrl);
      expect(item?.isSignedUrlValid, isTrue);
    });

    test('refresh reloads data without errors', () async {
      final notifier = container.read(adminVerificationProvider.notifier);
      await notifier.refresh();

      final state = container.read(adminVerificationProvider);
      expect(state.isLoading, isFalse);
      expect(state.items.length, 4);
      expect(state.errorMessage, isNull);
    });
  });
}
