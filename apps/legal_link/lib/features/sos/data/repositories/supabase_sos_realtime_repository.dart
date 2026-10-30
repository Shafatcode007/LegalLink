import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/sos_realtime_repository.dart';
import '../../domain/sos_channels.dart';
import '../channel_registry.dart';
import '../models/sos_request_dto.dart';

/// `sos:{district}` channels over Supabase Realtime postgres_changes
/// (INSERT + UPDATE on sos_requests filtered by district, TRD §6.5).
/// Rows are mapped with the same [SosRequestDto] the inbox uses.
class SupabaseSosRealtimeRepository implements SosRealtimeRepository {
  SupabaseSosRealtimeRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<SosChange> watchDistricts(Iterable<String> districts) {
    final wanted = sosDistricts(districts);
    late final StreamController<SosChange> controller;
    final registry = ChannelRegistry<RealtimeChannel>(
      open: (district) => _openChannel(district, controller),
      close: (channel) => unawaited(_client.removeChannel(channel)),
    );
    controller = StreamController<SosChange>(
      onListen: () => registry.sync(wanted),
      onCancel: registry.closeAll,
    );
    return controller.stream;
  }

  RealtimeChannel _openChannel(
    String district,
    StreamController<SosChange> sink,
  ) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'district',
      value: district,
    );
    return _client
        .channel(sosChannelTopic(district))
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sos_requests',
          filter: filter,
          callback: (p) => _emit(sink, SosChangeType.inserted, p),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'sos_requests',
          filter: filter,
          callback: (p) => _emit(sink, SosChangeType.updated, p),
        )
        .subscribe((status, error) => _onStatus(sink, district, status, error));
  }

  static void _emit(
    StreamController<SosChange> sink,
    SosChangeType type,
    PostgresChangePayload payload,
  ) {
    try {
      sink.add(SosChange(type, SosRequestDto.fromJson(payload.newRecord)));
    } catch (e, st) {
      // A malformed row must not tear down the whole feed.
      sink.addError(e, st);
    }
  }

  /// Fail loud (TRD P8): an empty feed must not hide a dead channel.
  static void _onStatus(
    StreamController<SosChange> sink,
    String district,
    RealtimeSubscribeStatus status,
    Object? error,
  ) {
    if (status == RealtimeSubscribeStatus.channelError ||
        status == RealtimeSubscribeStatus.timedOut) {
      sink.addError(
        error ?? StateError('${sosChannelTopic(district)}: $status'),
      );
    }
  }
}
