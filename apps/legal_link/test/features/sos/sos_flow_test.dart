import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/app/di.dart';
import 'package:legal_link/features/sos/data/models/sos_request_dto.dart';
import 'package:legal_link/features/sos/data/repositories/mock_sos_repository.dart';
import 'package:legal_link/features/sos/domain/entities/sos_accept_result.dart';
import 'package:legal_link/features/sos/domain/entities/sos_request_item.dart';
import 'package:legal_link/features/sos/domain/repositories/sos_repository.dart';
import 'package:legal_link/features/sos/presentation/notifiers/sos_form_notifier.dart';
import 'package:legal_link/features/sos/presentation/notifiers/sos_inbox_notifier.dart';
import 'package:legal_link/features/sos/presentation/screens/sos_broadcast_form_screen.dart';
import 'package:legal_link/features/sos/presentation/widgets/sos_alert_card.dart';
import 'package:legal_link/shared/widgets/sync_badge.dart';

void main() {
  group('SOS Domain & DTO serialization', () {
    test('SosRequestDto converts to and from JSON correctly', () {
      final item = SosRequestItem(
        id: 'sos-1234',
        clientId: 'client-999',
        personName: 'মোঃ করিম',
        thana: 'মিরপুর থানা',
        district: 'ঢাকা',
        court: 'ঢাকা সিএমএম আদালত',
        charges: 'ফৌজদারি কার্যবিধি ৫৪ ধারা',
        contactPhone: '+8801700000000',
        urgency: SosUrgency.critical,
        status: SosStatus.open,
        createdAt: DateTime(2026, 10, 24, 12, 0),
        notes: 'জরুরি সহায়তা প্রয়োজন',
      );

      final json = SosRequestDto.toJson(item);
      expect(json['id'], 'sos-1234');
      expect(json['person_name'], 'মোঃ করিম');
      expect(json['thana'], 'মিরপুর থানা');
      expect(json['status'], 'open');

      final deserialized = SosRequestDto.fromJson(json);
      expect(deserialized.id, item.id);
      expect(deserialized.personName, item.personName);
      expect(deserialized.thana, item.thana);
      expect(deserialized.status, item.status);
    });
  });

  group('Single Accept Flow & Losing Advocate UI (Sprint 2, Tasks 2 & 3)', () {
    late MockSosRepository mockRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = MockSosRepository();
      container = ProviderContainer(
        overrides: [sosRepositoryProvider.overrideWithValue(mockRepo)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'Single Accept Flow: Winning advocate transitions to "Case Created"',
      () async {
        final notifier = container.read(sosInboxProvider.notifier);
        await notifier.load();

        final state = container.read(sosInboxProvider);
        expect(state.items, isNotEmpty);
        final testAlertId = state.items.first.id;

        // 1. Advocate taps Accept -> returns success
        final result = await notifier.accept(testAlertId);
        expect(result, isA<SosAcceptSuccess>());

        final success = result as SosAcceptSuccess;
        expect(success.caseId, startsWith('CASE-'));

        // 2. State marks case as created and is no longer in acceptingIds
        final updatedState = container.read(sosInboxProvider);
        expect(updatedState.isAccepting(testAlertId), isFalse);
        expect(updatedState.isCaseCreated(testAlertId), isTrue);
        expect(updatedState.getCreatedCaseId(testAlertId), success.caseId);
        expect(updatedState.isAlreadyTaken(testAlertId), isFalse);
      },
    );

    test('Losing Advocate UI: Backend returning null transitions to "This SOS is already taken"', () async {
      final notifier = container.read(sosInboxProvider.notifier);
      await notifier.load();

      final state = container.read(sosInboxProvider);
      final testAlertId = state.items.first.id;

      // Simulate race condition where another advocate took it first (RPC returns null)
      mockRepo.simulateRaceConditionForId = testAlertId;

      // Tap Accept
      final result = await notifier.accept(testAlertId);
      expect(result, isA<SosAcceptAlreadyTaken>());

      // State marks as already taken
      final updatedState = container.read(sosInboxProvider);
      expect(updatedState.isAccepting(testAlertId), isFalse);
      expect(updatedState.isCaseCreated(testAlertId), isFalse);
      expect(updatedState.isAlreadyTaken(testAlertId), isTrue);
    });

    test('Decline Flow: Advocate declining removes item from inbox', () async {
      final notifier = container.read(sosInboxProvider.notifier);
      await notifier.load();

      final initialCount = container.read(sosInboxProvider).items.length;
      final targetId = container.read(sosInboxProvider).items.first.id;

      await notifier.decline(targetId);

      final updatedItems = container.read(sosInboxProvider).items;
      expect(updatedItems.length, initialCount - 1);
      expect(updatedItems.any((i) => i.id == targetId), isFalse);
    });
  });

  group('SosAlertCard UI Widget States', () {
    final sampleItem = SosRequestItem(
      id: 'sos-test-01',
      clientId: 'c-1',
      personName: 'আটক ব্যক্তি - শফিক',
      thana: 'ধানমন্ডি থানা',
      district: 'ঢাকা',
      charges: '৫৪ ধারা',
      contactPhone: '+8801711223344',
      status: SosStatus.open,
      createdAt: DateTime.now(),
      distanceKm: 2.4,
    );

    testWidgets('Renders open active alert with Accept & Decline buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosAlertCard(
              item: sampleItem,
              isAccepting: false,
              isCaseCreated: false,
              isAlreadyTaken: false,
              onAccept: () {},
              onDecline: () {},
            ),
          ),
        ),
      );

      expect(find.text('জরুরি SOS'), findsOneWidget);
      expect(find.text('আটককৃত ব্যক্তি: আটক ব্যক্তি - শফিক'), findsOneWidget);
      expect(find.text('গ্রহণ করুন (Accept)'), findsOneWidget);
      expect(find.text('পারবেন না (Decline)'), findsOneWidget);
      expect(find.textContaining('2.4 কিমি দূরে'), findsOneWidget);
    });

    testWidgets('Single Accept Flow: Renders "Case Created" when won', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosAlertCard(
              item: sampleItem,
              isAccepting: false,
              isCaseCreated: true,
              isAlreadyTaken: false,
              createdCaseId: 'CASE-2026-DHAKA-001',
              onAccept: () {},
              onDecline: () {},
            ),
          ),
        ),
      );

      expect(find.text('Case Created'), findsOneWidget);
      expect(
        find.text('মামলা তৈরি হয়েছে — আপনি দায়িত্ব পেয়েছেন'),
        findsOneWidget,
      );
      expect(find.text('মামলা নম্বর: CASE-2026-DHAKA-001'), findsOneWidget);
      expect(find.text('মামলার বিবরণ দেখুন →'), findsOneWidget);
      expect(find.text('ক্লায়েন্টকে কল করুন'), findsOneWidget);
    });

    testWidgets(
      'Losing Advocate: Renders "This SOS is already taken" when race is lost',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SosAlertCard(
                item: sampleItem,
                isAccepting: false,
                isCaseCreated: false,
                isAlreadyTaken: true,
                onAccept: () {},
                onDecline: () {},
              ),
            ),
          ),
        );

        expect(find.text('This SOS is already taken'), findsOneWidget);
        expect(
          find.text('এই SOS ইতিমধ্যে অন্য একজন আইনজীবী গ্রহণ করেছেন'),
          findsOneWidget,
        );
        expect(
          find.text(
            'দৌড়ে আপনি পেছনে পড়েছেন — অন্য একজন যাচাইকৃত আইনজীবী দ্রুত সাড়া দিয়েছেন।',
          ),
          findsOneWidget,
        );
        expect(find.text('ইনবক্স থেকে সরান (Dismiss)'), findsOneWidget);
        // Accept button should not exist
        expect(find.text('গ্রহণ করুন (Accept)'), findsNothing);
      },
    );
  });

  group('SyncBadge and SOS Form Offline/Queued States (Task 4)', () {
    test(
      'SyncBadge correctly reports queue warning (>=50) and blocking (>=100)',
      () {
        const normalBadge = SyncBadge(
          status: SyncStatus.queued,
          pendingCount: 10,
        );
        expect(normalBadge.isQueueWarning, isFalse);
        expect(normalBadge.isQueueBlocked, isFalse);

        const warningBadge = SyncBadge(
          status: SyncStatus.queued,
          pendingCount: 52,
        );
        expect(warningBadge.isQueueWarning, isTrue);
        expect(warningBadge.isQueueBlocked, isFalse);

        const blockedBadge = SyncBadge(
          status: SyncStatus.queued,
          pendingCount: 105,
        );
        expect(blockedBadge.isQueueWarning, isFalse);
        expect(blockedBadge.isQueueBlocked, isTrue);
      },
    );

    testWidgets('SyncBadge renders warning and blocked full banners', (
      tester,
    ) async {
      // 1. Warning banner
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SyncBadge(
              status: SyncStatus.queued,
              pendingCount: 60,
              isBanner: true,
            ),
          ),
        ),
      );

      expect(find.textContaining('সংযোগ দুর্বল'), findsOneWidget);
      expect(find.textContaining('60 অপেক্ষায়'), findsOneWidget);

      // 2. Blocked banner
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SyncBadge(
              status: SyncStatus.queued,
              pendingCount: 102,
              isBanner: true,
            ),
          ),
        ),
      );

      expect(
        find.textContaining('অপেক্ষারতার সীমা পূর্ণ (১০০)'),
        findsOneWidget,
      );
    });

    testWidgets(
      'SosBroadcastFormScreen renders 4 required fields, SyncBadge and 109 hotline',
      (tester) async {
        final mockRepo = MockSosRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sosRepositoryProvider.overrideWithValue(mockRepo)],
            child: const MaterialApp(home: SosBroadcastFormScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Check title and reassurance
        expect(find.text('জরুরি SOS পাঠান'), findsOneWidget);
        expect(find.text('সরকারি জরুরি সহায়তা ১০৯'), findsOneWidget);
        expect(find.text('কল করুন (Call 109)'), findsOneWidget);
        expect(find.text('আবশ্যকীয় তথ্য (Required)'), findsOneWidget);

        // 4 required fields present
        expect(find.text('আটককৃত ব্যক্তির নাম *'), findsOneWidget);
        expect(find.text('থানা (Thana) *'), findsOneWidget);
        expect(find.text('জেলা / আদালত *'), findsOneWidget);
        expect(find.text('জরুরি যোগাযোগের ফোন নম্বর *'), findsOneWidget);

        // Switch to offline mode
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        expect(find.text('অফলাইন'), findsOneWidget);
        expect(find.text('অফলাইনে জমা দিন (Queue Offline)'), findsOneWidget);
      },
    );

    test(
      'SosFormNotifier queues request when offline and flushes on reconnect',
      () async {
        final mockRepo = MockSosRepository();
        final container = ProviderContainer(
          overrides: [sosRepositoryProvider.overrideWithValue(mockRepo)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(sosFormProvider.notifier);
        notifier.updatePersonName('মোস্তফা কামাল');
        notifier.updateThana('ধানমন্ডি');
        notifier.updateContactPhone('01711223344');

        // Toggle offline
        notifier.toggleOffline(true);
        expect(container.read(sosFormProvider).isOffline, isTrue);

        // Submit offline
        await notifier.submitSos();
        final offlineState = container.read(sosFormProvider);
        expect(offlineState.syncStatus, SyncStatus.queued);
        expect(offlineState.pendingQueueCount, 1);
        expect(offlineState.submittedRequest?.isQueuedLocally, isTrue);

        // Reconnect online -> flushes queue
        notifier.toggleOffline(false);
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final onlineState = container.read(sosFormProvider);
        expect(onlineState.isOffline, isFalse);
        expect(onlineState.pendingQueueCount, 0);
        expect(onlineState.syncStatus, SyncStatus.synced);
      },
    );
  });

  group('Composition Root & Dependency Injection (TRD §8.1)', () {
    test('createDiOverrides binds SupabaseSosRepository by default', () {
      final overrides = createDiOverrides();
      expect(overrides.length, greaterThanOrEqualTo(2));
    });

    test('createDiOverrides allows mocking for deterministic unit tests', () {
      final mock = MockSosRepository();
      final overrides = createDiOverrides(sosRepository: mock);
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      final repo = container.read(sosRepositoryProvider);
      expect(repo, isA<MockSosRepository>());
    });
  });
}
