import '../entities/sos_alert.dart';

/// Live SOS feed for an advocate's districts (TRD §6.5 `sos:{district}`).
/// Visibility is enforced by RLS on the server, not by this interface.
abstract interface class SosRealtimeRepository {
  /// One channel per district; cancelling the subscription closes them.
  Stream<SosChange> watchDistricts(Iterable<String> districts);
}
