import '../../domain/entities/sos_accept_result.dart';
import '../../domain/entities/sos_request_item.dart';
import '../../domain/repositories/sos_repository.dart';

/// In-memory mock repository for deterministic unit/widget testing of SOS flows.
class MockSosRepository implements SosRepository {
  MockSosRepository({
    List<SosRequestItem>? initialItems,
    this.simulateRaceConditionForId,
  }) {
    _items = initialItems ?? _defaultMockItems();
  }

  late List<SosRequestItem> _items;
  final List<SosRequestItem> _outbox = [];

  /// If set to a specific SOS ID, `acceptSos(id)` will simulate losing the race
  /// by returning `null` (backend returned null).
  String? simulateRaceConditionForId;

  static List<SosRequestItem> _defaultMockItems() {
    final now = DateTime.now();
    return [
      SosRequestItem(
        id: 'sos-101',
        clientId: 'client-101',
        personName: 'মোঃ শফিকুল ইসলাম (Shafiqul Islam)',
        thana: 'ধানমন্ডি মডেল থানা (Dhanmondi Thana)',
        district: 'ঢাকা (Dhaka)',
        court: 'ঢাকা মহানগর দায়রা জজ আদালত',
        charges: 'ফৌজদারি কার্যবিধি ৫৪ ধারা / সন্দেহভাজন আটক',
        urgency: SosUrgency.critical,
        contactPhone: '+880 1711-223344',
        notes: 'থানায় নিয়ে যাওয়া হয়েছে, জরুরি জামিন আইনজীবী প্রয়োজন।',
        createdAt: now.subtract(const Duration(minutes: 6)),
        distanceKm: 1.8,
      ),
      SosRequestItem(
        id: 'sos-102',
        clientId: 'client-102',
        personName: 'তানভীর আহমেদ চৌধুরী (Tanvir Ahmed)',
        thana: 'গুলশান থানা (Gulshan Thana)',
        district: 'ঢাকা (Dhaka)',
        court: 'চিফ মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত',
        charges: 'সাইবার সুরক্ষা আইন / ডিজিটাল অভিযোগ',
        urgency: SosUrgency.high,
        contactPhone: '+880 1819-556677',
        notes: 'জিজ্ঞাসাবাদের জন্য রিমান্ড শুনানির সম্ভাবনা।',
        createdAt: now.subtract(const Duration(minutes: 18)),
        distanceKm: 3.5,
      ),
      SosRequestItem(
        id: 'sos-103',
        clientId: 'client-103',
        personName: 'রাশেদ খান (Rashed Khan)',
        thana: 'মিরপুর মডেল থানা (Mirpur Thana)',
        district: 'ঢাকা (Dhaka)',
        court: 'ঢাকা জেলা ও দায়রা জজ আদালত',
        charges: 'জমি সংক্রান্ত বিরোধ / হঠাৎ পুলিশ তল্লাশি',
        urgency: SosUrgency.medium,
        contactPhone: '+880 1912-778899',
        createdAt: now.subtract(const Duration(minutes: 42)),
        distanceKm: 4.2,
      ),
    ];
  }

  @override
  List<SosRequestItem> getCachedInbox() => List.unmodifiable(_items);

  @override
  Future<List<SosRequestItem>> getAdvocateInbox() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(_items);
  }

  @override
  Future<CaseCreationResult?> acceptSos(String sosId) async {
    // Simulated network latency
    await Future.delayed(const Duration(milliseconds: 250));

    // Simulate race condition if configured or if item does not exist/already accepted
    if (simulateRaceConditionForId == sosId) {
      _items = _items.where((i) => i.id != sosId).toList();
      return null;
    }

    final index = _items.indexWhere((i) => i.id == sosId);
    if (index == -1) {
      return null;
    }

    final acceptedItem = _items[index].copyWith(
      status: SosStatus.accepted,
      acceptedAt: DateTime.now(),
    );
    _items[index] = acceptedItem;

    final caseId =
        'CASE-2026-${sosId.replaceAll('-', '').substring(0, 6).toUpperCase()}';
    return SosAcceptSuccess(sosRequest: acceptedItem, caseId: caseId);
  }

  @override
  Future<void> declineSos(String sosId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _items = _items.where((i) => i.id != sosId).toList();
  }

  @override
  Future<SosRequestItem> broadcastSos(
    SosRequestItem request, {
    required bool isOffline,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (isOffline) {
      final queued = request.copyWith(isQueuedLocally: true);
      _outbox.add(queued);
      return queued;
    }
    _items.insert(0, request);
    return request;
  }

  @override
  Future<List<SosRequestItem>> flushOutbox() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final flushed = <SosRequestItem>[];
    for (final item in List<SosRequestItem>.from(_outbox)) {
      final saved = item.copyWith(isQueuedLocally: false);
      flushed.add(saved);
      _items.insert(0, saved);
    }
    _outbox.clear();
    return flushed;
  }

  @override
  Future<void> refresh() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
