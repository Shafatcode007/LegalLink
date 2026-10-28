import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/features/sos/data/supabase_client_sos_repository.dart';
import 'package:legal_link/features/sos/domain/sos_draft.dart';

import 'support/supabase_fixture.dart';

const draft = SosDraft(
  personName: 'Person',
  policeStation: 'Dhanmondi',
  districtCourt: 'Dhaka',
  contactPhone: '+8801712345678',
);

Map<String, dynamic> savedRequest() => {
  'id': 'sos-id',
  'client_id': 'user-id',
  'person_name': 'Person',
  'thana': 'Dhanmondi',
  'district': 'Dhaka',
  'contact_phone': '+8801712345678',
  'status': 'open',
  'created_at': '2026-10-27T00:00:00Z',
  'expires_at': '2026-10-28T00:00:00Z',
};

void main() {
  test(
    'retry recovers a saved SOS after a lost response without posting twice',
    () async {
      var posts = 0;
      final fixture = SupabaseFixture((request) async {
        if (request.method == 'POST') {
          posts++;
          throw StateError('response lost after server commit');
        }
        return [savedRequest()];
      });
      addTearDown(fixture.client.dispose);
      await fixture.signIn(role: 'client');
      final repository = SupabaseClientSosRepository(fixture.client);
      const value = SosDraft(
        requestId: 'sos-id',
        personName: 'Person',
        policeStation: 'Dhanmondi',
        districtCourt: 'Dhaka',
        contactPhone: '+8801712345678',
      );
      await expectLater(
        repository.submit(value),
        throwsA(ClientSosFailure.unavailable),
      );
      expect((await repository.submit(value)).id, 'sos-id');
      expect(posts, 1);
    },
  );
  test(
    'live SOS returns the server identifier and authenticates ownership',
    () async {
      final fixture = SupabaseFixture((request) async => savedRequest());
      addTearDown(fixture.client.dispose);
      await fixture.signIn(role: 'client');
      final saved = await SupabaseClientSosRepository(fixture.client)
          .submit(draft);
      expect(saved.id, 'sos-id');
      expect(saved.status, ClientSosStatus.open);
      final body = jsonDecode(fixture.requests.single.body);
      expect(body['client_id'], 'user-id');
      expect(body['thana'], 'Dhanmondi');
      expect(body['district'], 'Dhaka');
      expect(body.keys, isNot(contains('advocate_id')));
    },
  );

  test('live failures propagate and never become a successful demo', () async {
    final fixture = SupabaseFixture(
      (request) async => throw StateError('offline'),
    );
    addTearDown(fixture.client.dispose);
    await fixture.signIn(role: 'client');
    await expectLater(
      SupabaseClientSosRepository(fixture.client).submit(draft),
      throwsA(isA<ClientSosFailure>()),
    );
  });

  test(
    'cancel applies both request ownership and open-state filters',
    () async {
      final fixture = SupabaseFixture(
        (request) async => [
          {...savedRequest(), 'status': 'cancelled'},
        ],
      );
      addTearDown(fixture.client.dispose);
      await fixture.signIn(role: 'client');
      final result = await SupabaseClientSosRepository(fixture.client)
          .cancel('sos-id');
      final request = fixture.requests.single;
      expect(result.status, ClientSosStatus.cancelled);
      expect(request.url.queryParameters['client_id'], 'eq.user-id');
      expect(request.url.queryParameters['status'], 'eq.open');
    },
  );
}
