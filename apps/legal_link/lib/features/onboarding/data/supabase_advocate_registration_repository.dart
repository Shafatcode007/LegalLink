import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/advocate_registration.dart';

class SupabaseAdvocateRegistrationRepository
    implements AdvocateRegistrationRepository {
  SupabaseAdvocateRegistrationRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<void> submit(String userId, AdvocateRegistration registration) async {
    _validate(userId, registration);
    try {
      final existing = await _existing(userId);
      if (existing == null && registration.pin.isEmpty) {
        throw RegistrationFailure.invalid;
      }
      await _client.rpc(
        'submit_verification',
        params: _parameters(registration, existing == null),
      );
      await _savePractice(userId, registration, existing);
      await _client.rpc(
        'update_advocate_documents',
        params: {
          'p_sanad_url': registration.sanadReference,
          'p_nid_url': registration.nidReference,
        },
      );
      if (registration.avatarReference != null) {
        await _client
            .from('profiles')
            .update({'avatar_url': registration.avatarReference})
            .eq('id', userId);
      }
    } on PostgrestException catch (error) {
      throw _failure(error.message);
    } catch (error) {
      if (error is RegistrationFailure) rethrow;
      throw RegistrationFailure.unavailable;
    }
  }

  void _validate(String id, AdvocateRegistration registration) {
    final user = _client.auth.currentUser;
    if (user == null) throw RegistrationFailure.unauthenticated;
    if (user.id != id || user.appMetadata['role'] != 'advocate') {
      throw RegistrationFailure.forbidden;
    }
    if (!registration.isValid ||
        !registration.validPin ||
        registration.yearsPractice < 0) {
      throw RegistrationFailure.invalid;
    }
  }

  Future<Map<String, dynamic>?> _existing(String id) => _client
      .from('advocates')
      .select('profile_id,verification,attempts,availability')
      .eq('profile_id', id)
      .maybeSingle();

  Map<String, dynamic> _parameters(AdvocateRegistration value, bool isNew) => {
    'p_bar_council_no': value.barCouncilNumber,
    'p_courts': value.courts,
    'p_districts': value.districts,
    'p_specializations': value.specializations
        .map(
          (item) =>
              item == Specialization.womenAndChild ? 'women_child' : item.name,
        )
        .toList(),
    'p_languages': value.languages.toList(),
    'p_fee_min_bdt': '${value.feeMin}.00',
    'p_fee_max_bdt': '${value.feeMax}.00',
    'p_pin': isNew ? value.pin : null,
    'p_nid_number': value.nid,
  };

  Future<void> _savePractice(
    String id,
    AdvocateRegistration value,
    Map<String, dynamic>? existing,
  ) async {
    final availability = Map<String, dynamic>.from(
      existing?['availability'] as Map? ?? const {},
    );
    availability['sos'] = value.availableForSos;
    await _client
        .from('advocates')
        .update({
          'years_practice': value.yearsPractice,
          'availability': availability,
        })
        .eq('profile_id', id);
  }

  RegistrationFailure _failure(String message) {
    if (message.contains('max_verification_attempts_reached')) {
      return RegistrationFailure.attemptsExhausted;
    }
    if (message.contains('pin_guard')) return RegistrationFailure.pinProtected;
    if (message.contains('caller must')) return RegistrationFailure.forbidden;
    return RegistrationFailure.unavailable;
  }
}
