import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/sos_draft.dart';

class SupabaseClientSosRepository extends SosRepository {
  SupabaseClientSosRepository(this._client);
  final SupabaseClient _client;
  final _attempted = <String>{};

  String _owner() {
    final user = _client.auth.currentUser;
    if (user == null) throw ClientSosFailure.unauthenticated;
    if (user.appMetadata['role'] != 'client') throw ClientSosFailure.forbidden;
    return user.id;
  }

  @override
  Future<ClientSosRequest> submit(SosDraft draft) async {
    final owner = _owner();
    if (!draft.isValid) throw ClientSosFailure.invalid;
    final id = draft.requestId ?? newSosRequestId();
    try {
      if (!_attempted.add(id)) {
        final existing = await _client
            .from('sos_requests')
            .select()
            .eq('id', id)
            .eq('client_id', owner)
            .maybeSingle();
        if (existing != null) return _decode(existing);
      }
      final row = await _client
          .from('sos_requests')
          .insert(_payload(draft, owner, id))
          .select()
          .single();
      return _decode(row);
    } on PostgrestException catch (error) {
      if (error.code == '23505') return _fetch(id);
      if (error.message.contains('sos_rate_limit_exceeded')) {
        throw ClientSosFailure.rateLimited;
      }
      throw ClientSosFailure.unavailable;
    } catch (error) {
      if (error is ClientSosFailure) rethrow;
      throw ClientSosFailure.unavailable;
    }
  }

  @override
  Future<ClientSosRequest?> currentOpen() async {
    try {
      final row = await _client
          .from('sos_requests')
          .select()
          .eq('client_id', _owner())
          .eq('status', 'open')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null ? null : _decode(row);
    } catch (error) {
      if (error is ClientSosFailure) rethrow;
      throw ClientSosFailure.unavailable;
    }
  }

  Map<String, dynamic> _payload(SosDraft draft, String owner, String id) => {
    'id': id,
    'client_id': owner,
    'person_name': draft.personName,
    'thana': draft.policeStation,
    'district': draft.districtCourt,
    'court': draft.court.isEmpty ? null : draft.court,
    'charges': draft.charges.isEmpty ? null : draft.charges,
    'arrested_at': draft.arrestTime?.toUtc().toIso8601String(),
    'person_nid': draft.nid.isEmpty ? null : draft.nid,
    'urgency': draft.urgency.name,
    'contact_phone': draft.contactPhone,
  };

  ClientSosRequest _decode(Map<String, dynamic> row) => ClientSosRequest(
    id: row['id'] as String,
    district: row['district'] as String,
    status: ClientSosStatus.values.byName(row['status'] as String),
    expiresAt: DateTime.tryParse(row['expires_at'] as String? ?? ''),
    advocateId: row['advocate_id'] as String?,
  );

  Future<ClientSosRequest> _fetch(String id) async {
    final row = await _client
        .from('sos_requests')
        .select()
        .eq('id', id)
        .eq('client_id', _owner())
        .single();
    return _decode(row);
  }

  @override
  Future<ClientSosRequest> cancel(String id) async {
    try {
      final rows = await _client
          .from('sos_requests')
          .update({'status': 'cancelled'})
          .eq('id', id)
          .eq('client_id', _owner())
          .eq('status', 'open')
          .select();
      if (rows.isEmpty) throw ClientSosFailure.stateChanged;
      return _decode(rows.single);
    } catch (error) {
      if (error is ClientSosFailure) rethrow;
      throw ClientSosFailure.unavailable;
    }
  }

  @override
  Stream<ClientSosRequest> watch(String id, String district) {
    final events = StreamController<ClientSosRequest>();
    Timer? timer;
    RealtimeChannel? channel;
    Future<void> refresh() async {
      try {
        final value = await _fetch(id);
        if (!events.isClosed) events.add(value);
      } catch (_) {
        if (!events.isClosed) events.addError(ClientSosFailure.unavailable);
      }
    }

    events.onListen = () {
      channel = _client
          .channel('sos:$district')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'sos_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'district',
              value: district,
            ),
            callback: (payload) {
              if (payload.newRecord['id'] == id) refresh();
            },
          )
          .subscribe();
      refresh();
      timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
    };
    events.onCancel = () async {
      timer?.cancel();
      if (channel != null) await _client.removeChannel(channel!);
      await events.close();
    };
    return events.stream;
  }
}
