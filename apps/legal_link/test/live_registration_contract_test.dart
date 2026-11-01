import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/features/onboarding/data/supabase_advocate_registration_repository.dart';
import 'package:legal_link/features/onboarding/domain/advocate_registration.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/supabase_fixture.dart';

AdvocateRegistration application() => const AdvocateRegistration(
  nid: '1234567890',
  barCouncilNumber: 'BAR-42',
  courts: ['Dhaka Court'],
  districts: ['Dhaka'],
  specializations: {Specialization.womenAndChild},
  feeMin: 1000,
  feeMax: 5000,
  languages: {'bn', 'en'},
  pin: '4826',
  yearsPractice: 5,
  availableForSos: true,
  sanadReference: 'user-id/sanad.jpg',
  nidReference: 'user-id/nid.jpg',
);

void main() {
  test(
    'registration uses the published RPC and never sends PIN security columns',
    () async {
      final fixture = SupabaseFixture(
        (request) async =>
            request.method == 'GET' ? [] : {'profile_id': 'user-id'},
      );
      addTearDown(fixture.client.dispose);
      await fixture.signIn();
      await SupabaseAdvocateRegistrationRepository(fixture.client)
          .submit('user-id', application());
      final rpc = fixture.requests.singleWhere(
        (r) => r.url.path.endsWith('/submit_verification'),
      );
      final body = jsonDecode(rpc.body) as Map<String, dynamic>;
      expect(body, containsPair('p_profile_id', 'user-id'));
      expect(body, containsPair('p_sanad_url', 'user-id/sanad.jpg'));
      expect(body, containsPair('p_nid_url', 'user-id/nid.jpg'));
      expect(body, containsPair('p_nid_number', '1234567890'));
      expect(body, containsPair('p_pin', '4826'));
      expect(body, containsPair('p_fee_min_bdt', '1000.00'));
      expect(body, containsPair('p_fee_max_bdt', '5000.00'));
      expect(body, containsPair('p_specializations', ['women_child']));
      expect(body.keys, isNot(contains('pin_hash')));
      expect(
        fixture.requests.any((r) => r.body.contains('pin_fail_count')),
        false,
      );
      expect(
        fixture.requests.any(
          (r) => r.url.path.endsWith('/update_advocate_documents'),
        ),
        false,
      );
    },
  );

  test('registration works without the removed document RPC', () async {
    final fixture = SupabaseFixture((request) async {
      if (request.url.path.endsWith('/update_advocate_documents')) {
        throw const PostgrestException(
          message: 'RPC not found',
          code: 'PGRST202',
        );
      }
      return request.method == 'GET' ? [] : {'profile_id': 'user-id'};
    });
    addTearDown(fixture.client.dispose);
    await fixture.signIn();
    await expectLater(
      SupabaseAdvocateRegistrationRepository(fixture.client)
          .submit('user-id', application()),
      completes,
    );
  });

  for (final error in [
    're_apply_cap_exceeded',
    'max_verification_attempts_reached',
  ]) {
    test('registration localizes the backend cap $error', () async {
      final fixture = SupabaseFixture((request) async {
        if (request.url.path.endsWith('/submit_verification')) {
          throw PostgrestException(message: error, code: 'P0001');
        }
        return [];
      });
      addTearDown(fixture.client.dispose);
      await fixture.signIn();
      await expectLater(
        SupabaseAdvocateRegistrationRepository(fixture.client)
            .submit('user-id', application()),
        throwsA(RegistrationFailure.attemptsExhausted),
      );
    });
  }

  test(
    'registration rejects a different account before making a request',
    () async {
      final fixture = SupabaseFixture((request) async => {});
      addTearDown(fixture.client.dispose);
      await fixture.signIn();
      await expectLater(
        SupabaseAdvocateRegistrationRepository(fixture.client)
            .submit('another-user', application()),
        throwsA(isA<RegistrationFailure>()),
      );
      expect(fixture.requests, isEmpty);
    },
  );

  test(
    'retry after profile creation preserves the existing approval PIN',
    () async {
      final fixture = SupabaseFixture(
        (request) async => request.method == 'GET'
            ? [
                {
                  'profile_id': 'user-id',
                  'verification': 'pending',
                  'attempts': 0,
                },
              ]
            : {'profile_id': 'user-id'},
      );
      addTearDown(fixture.client.dispose);
      await fixture.signIn();
      await SupabaseAdvocateRegistrationRepository(fixture.client)
          .submit('user-id', application());
      final request = fixture.requests.singleWhere(
        (r) => r.url.path.endsWith('/submit_verification'),
      );
      expect(jsonDecode(request.body)['p_pin'], isNull);
    },
  );
}
