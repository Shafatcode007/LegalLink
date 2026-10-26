import 'package:riverpod/riverpod.dart';

import '../entities/sos_request_item.dart';

enum SosChangeType { inserted, updated }

class SosChange {
  const SosChange(this.type, this.request);

  final SosChangeType type;
  final SosRequestItem request;
}

/// Live SOS feed for an advocate's districts (TRD §6.5 `sos:{district}`).
/// Visibility is enforced by RLS on the server, not by this interface.
abstract interface class SosRealtimeRepository {
  /// One channel per district; cancelling the subscription closes them.
  Stream<SosChange> watchDistricts(Iterable<String> districts);
}

/// Abstract provider token declared in domain layer (TRD §8.1).
///
/// Concrete bindings are provided ONLY in `lib/app/di.dart`.
final sosRealtimeRepositoryProvider = Provider<SosRealtimeRepository>((ref) {
  throw UnimplementedError(
    'sosRealtimeRepositoryProvider must be overridden in lib/app/di.dart',
  );
});
