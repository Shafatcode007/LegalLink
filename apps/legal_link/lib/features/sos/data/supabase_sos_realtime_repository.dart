import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/sos_alert.dart';
import '../domain/repositories/sos_realtime_repository.dart';
import '../domain/sos_channels.dart';
import 'channel_registry.dart';
import 'sos_alert_mapper.dart';

/// `sos:{district}` channels over Supabase Realtime postgres_changes
/// (INSERT + UPDATE on sos_requests filtered by district, TRD §6.5).
class SupabaseSosRealtimeRepository implements SosRealtimeRepository {
  SupabaseSosRealtimeRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<SosChange> watchDistricts(Iterable<String> districts) {
    final wanted = sosDistricts(districts);
    late final StreamController<SosChange> controller;
    late final ChannelRegistry<RealtimeChannel> registry;

    void emit(SosChangeType type, PostgresChangePayload payload) {
      try {
        controller.add(SosChange(type, sosAlertFromRecord(payload.newRecord)));
      } on FormatException catch (e, st) {
        controller.addError(e, st);
      }
    }

    RealtimeChannel open(String district) {
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
            callback: (p) => emit(SosChangeType.inserted, p),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'sos_requests',
            filter: filter,
            callback: (p) => emit(SosChangeType.updated, p),
          )
          .subscribe((status, error) {
            // Fail loud (TRD P8): an empty feed must not hide a dead channel.
            if (status == RealtimeSubscribeStatus.channelError ||
                status == RealtimeSubscribeStatus.timedOut) {
              controller.addError(
                error ?? StateError('${sosChannelTopic(district)}: $status'),
              );
            }
          });
    }

    registry = ChannelRegistry<RealtimeChannel>(
      open: open,
      close: (channel) => unawaited(_client.removeChannel(channel)),
    );
    controller = StreamController<SosChange>(
      onListen: () => registry.sync(wanted),
      onCancel: registry.closeAll,
    );
    return controller.stream;
  }
}
