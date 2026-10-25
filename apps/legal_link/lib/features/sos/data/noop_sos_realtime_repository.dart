import '../domain/entities/sos_alert.dart';
import '../domain/repositories/sos_realtime_repository.dart';

/// Used when no Supabase backend is configured: the feed is simply empty.
class NoopSosRealtimeRepository implements SosRealtimeRepository {
  const NoopSosRealtimeRepository();

  @override
  Stream<SosChange> watchDistricts(Iterable<String> districts) =>
      const Stream.empty();
}
