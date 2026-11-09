import 'package:flutter_test/flutter_test.dart';
import 'package:legal_link/features/onboarding/data/supabase_advocate_registration_repository.dart';
import 'package:legal_link/features/onboarding/domain/advocate_application.dart';
import 'package:legal_link/features/onboarding/domain/advocate_registration.dart';

import 'live_registration_contract_test.dart' show application;
import 'support/supabase_fixture.dart';

void main() {
  test(
    'restores the own application without reading PIN security fields',
    () async {
      final fixture = SupabaseFixture(
        (_) async => [
          {
            'verification': 'rejected',
            'rejection_reason': 'Replace Sanad',
            'attempts': 1,
            'nid_number': '1234567890',
            'bar_council_no': 'BAR-42',
            'courts': ['Dhaka Court'],
            'districts': ['Dhaka'],
            'specializations': ['women_child'],
            'languages': ['bn', 'en'],
            'fee_min_bdt': '1000.00',
            'fee_max_bdt': '5000.00',
            'sanad_url': 'user-id/sanad.jpg',
            'nid_url': 'user-id/nid.jpg',
            'years_practice': 5,
            'availability': {'sos': true},
          },
        ],
      );
      addTearDown(fixture.client.dispose);
      await fixture.signIn();
      final app = await SupabaseAdvocateRegistrationRepository(fixture.client)
          .getApplication('user-id');
      expect(app!.verification, AdvocateVerification.rejected);
      expect(app.rejectionReason, 'Replace Sanad');
      expect(app.registration.isValid, true);
      expect(app.registration.pin, isEmpty);
      expect(app.canResubmit, true);
      final query = fixture.requests.single.url.queryParameters;
      expect(query['profile_id'], 'eq.user-id');
      expect(query['select'], isNot(contains('pin')));
      expect(query['select'], isNot(contains('*')));
    },
  );

  test('no application is distinct from a failed status read', () async {
    final fixture = SupabaseFixture((_) async => []);
    addTearDown(fixture.client.dispose);
    await fixture.signIn();
    expect(
      await SupabaseAdvocateRegistrationRepository(fixture.client)
          .getApplication('user-id'),
      isNull,
    );
  });

  test(
    'another account cannot be read through the registration repository',
    () async {
      final fixture = SupabaseFixture((_) async => []);
      addTearDown(fixture.client.dispose);
      await fixture.signIn();
      await expectLater(
        SupabaseAdvocateRegistrationRepository(fixture.client)
            .getApplication('other-user'),
        throwsA(RegistrationFailure.forbidden),
      );
      expect(fixture.requests, isEmpty);
    },
  );

  for (final entry in {
    'verified': RegistrationFailure.alreadyVerified,
    'rejected': RegistrationFailure.attemptsExhausted,
  }.entries) {
    test('${entry.key} is blocked before the submission RPC', () async {
      final fixture = SupabaseFixture(
        (_) async => [
          {'verification': entry.key, 'attempts': 3},
        ],
      );
      addTearDown(fixture.client.dispose);
      await fixture.signIn();
      await expectLater(
        SupabaseAdvocateRegistrationRepository(fixture.client)
            .submit('user-id', application()),
        throwsA(entry.value),
      );
      expect(fixture.requests.any((r) => r.method != 'GET'), false);
    });
  }
}
