import 'package:riverpod/riverpod.dart';

import '../entities/case_creation_result.dart';
import '../entities/sos_request_item.dart';

/// Pure Dart repository interface for SOS operations (Role B2, Sprint 2).
///
/// TRD §8.1: Pure Dart: No flutter, supabase_flutter, hive, data/, or presentation/ imports.
abstract class SosRepository {
  /// Fetches open SOS alerts for the advocate's district.
  Future<List<SosRequestItem>> getAdvocateInbox();

  /// Synchronously provides cached items for immediate initial render.
  List<SosRequestItem> getCachedInbox();

  /// Advocate attempts to accept an SOS request.
  ///
  /// Calls `accept_sos(uuid)` RPC.
  /// - If the RPC returns `null` or conflict error (lost race to another advocate), returns `null`.
  /// - On success (winning advocate), returns [CaseCreationResult] with the generated case ID.
  Future<CaseCreationResult?> acceptSos(String sosId);

  /// Advocate declines / dismisses an SOS alert from their inbox.
  Future<void> declineSos(String sosId);

  /// Client broadcasts an emergency SOS (can be queued locally when offline).
  Future<SosRequestItem> broadcastSos(
    SosRequestItem request, {
    required bool isOffline,
  });

  /// Flushes locally queued SOS requests once connectivity is restored.
  Future<List<SosRequestItem>> flushOutbox();

  /// Refreshes the advocate inbox from the server.
  Future<void> refresh();
}

/// Abstract provider token declared in domain layer (TRD §8.1).
///
/// Concrete bindings are provided ONLY in `lib/app/di.dart`.
final sosRepositoryProvider = Provider<SosRepository>((ref) {
  throw UnimplementedError(
    'sosRepositoryProvider must be overridden in lib/app/di.dart',
  );
});
