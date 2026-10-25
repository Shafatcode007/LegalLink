import '../../domain/entities/sos_accept_result.dart';
import '../../domain/entities/sos_request_item.dart';
import '../../domain/repositories/sos_repository.dart';
import '../sources/supabase_sos_data_source.dart';

/// Concrete repository implementing [SosRepository] wired to real Supabase backend.
///
/// Handles single-accept flow, race condition handling when backend returns null,
/// and offline queuing for client SOS submissions.
class SupabaseSosRepository implements SosRepository {
  SupabaseSosRepository({SupabaseSosDataSource? dataSource})
    : _dataSource = dataSource ?? SupabaseSosDataSource();

  final SupabaseSosDataSource _dataSource;
  List<SosRequestItem> _cachedInbox = [];
  final List<SosRequestItem> _localOutbox = [];

  @override
  List<SosRequestItem> getCachedInbox() {
    return List.unmodifiable(_cachedInbox);
  }

  @override
  Future<List<SosRequestItem>> getAdvocateInbox() async {
    final items = await _dataSource.fetchOpenAlerts();
    _cachedInbox = items;
    return List.unmodifiable(_cachedInbox);
  }

  @override
  Future<SosAcceptResult> acceptSos(String sosId) async {
    final result = await _dataSource.callAcceptSos(sosId);

    // If accept succeeded, mark locally as accepted
    if (result is SosAcceptSuccess) {
      _cachedInbox = _cachedInbox.map((item) {
        if (item.id == sosId) {
          return item.copyWith(
            status: SosStatus.accepted,
            acceptedAt: DateTime.now(),
          );
        }
        return item;
      }).toList();
    } else if (result is SosAcceptAlreadyTaken) {
      // If lost the race, remove or mark as taken
      _cachedInbox = _cachedInbox.where((item) => item.id != sosId).toList();
    }

    return result;
  }

  @override
  Future<void> declineSos(String sosId) async {
    // Remove declined alert from advocate's inbox locally
    _cachedInbox = _cachedInbox.where((item) => item.id != sosId).toList();
  }

  @override
  Future<SosRequestItem> broadcastSos(
    SosRequestItem request, {
    required bool isOffline,
  }) async {
    if (isOffline) {
      // Local queueing only for client submissions (ADR-016: accept_sos is realtime-only)
      final queued = request.copyWith(isQueuedLocally: true);
      _localOutbox.add(queued);
      return queued;
    }

    return _dataSource.insertSos(request);
  }

  @override
  Future<List<SosRequestItem>> flushOutbox() async {
    if (_localOutbox.isEmpty) return const [];
    final flushed = <SosRequestItem>[];

    for (final item in List<SosRequestItem>.from(_localOutbox)) {
      final saved = await _dataSource.insertSos(
        item.copyWith(isQueuedLocally: false),
      );
      flushed.add(saved);
      _localOutbox.removeWhere((i) => i.id == item.id);
    }
    return flushed;
  }

  @override
  Future<void> refresh() async {
    await getAdvocateInbox();
  }
}
