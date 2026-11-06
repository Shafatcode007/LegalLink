import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/advocate_registration.dart';
import '../domain/advocate_application.dart';

class SupabaseAdvocateRegistrationRepository
    implements AdvocateRegistrationRepository {
  SupabaseAdvocateRegistrationRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<AdvocateApplication?> getApplication(String userId) async {
    _validateUser(userId);
    try {
      final row = await _client
          .from('advocates')
          .select(
            'verification,rejection_reason,attempts,nid_number,bar_council_no,'
            'courts,districts,specializations,languages,fee_min_bdt,fee_max_bdt,'
            'sanad_url,nid_url,years_practice,availability',
          )
          .eq('profile_id', userId)
          .maybeSingle();
      return row == null ? null : _application(row);
    } catch (_) {
      throw RegistrationFailure.unavailable;
    }
  }

  AdvocateApplication _application(Map<String, dynamic> row) =>
      AdvocateApplication(
        verification: AdvocateVerification.values.byName(row['verification']),
        rejectionReason: row['rejection_reason'] as String?,
        attempts: (row['attempts'] as num?)?.toInt() ?? 0,
        registration: AdvocateRegistration(
          nid: row['nid_number'] as String? ?? '',
          barCouncilNumber: row['bar_council_no'] as String? ?? '',
          courts: List<String>.from(row['courts'] ?? []),
          districts: List<String>.from(row['districts'] ?? []),
          specializations: {
            for (final item in row['specializations'] ?? [])
              Specialization.values.byName(
                item == 'women_child' ? 'womenAndChild' : item,
              ),
          },
          languages: Set<String>.from(row['languages'] ?? []),
          feeMin: num.parse('${row['fee_min_bdt'] ?? 0}').toInt(),
          feeMax: num.parse('${row['fee_max_bdt'] ?? 0}').toInt(),
          sanadReference: row['sanad_url'] as String? ?? '',
          nidReference: row['nid_url'] as String? ?? '',
          yearsPractice: (row['years_practice'] as num?)?.toInt() ?? 0,
          availableForSos: row['availability']?['sos'] == true,
        ),
      );

  @override
  Future<void> submit(String userId, AdvocateRegistration registration) async {
    _validate(userId, registration);
    try {
      final existing = await _existing(userId);
      if (existing?['verification'] == 'verified') {
        throw RegistrationFailure.alreadyVerified;
      }
      if ((existing?['attempts'] as num? ?? 0) >= 3) {
        throw RegistrationFailure.attemptsExhausted;
      }
      if (existing == null && registration.pin.isEmpty) {
        throw RegistrationFailure.invalid;
      }
      await _client.rpc(
        'submit_verification',
        params: _parameters(userId, registration, existing == null),
      );
      await _savePractice(userId, registration, existing);
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
    _validateUser(id);
    if (!registration.isValid ||
        !registration.validPin ||
        registration.yearsPractice < 0) {
      throw RegistrationFailure.invalid;
    }
  }

  void _validateUser(String id) {
    final user = _client.auth.currentUser;
    if (user == null) throw RegistrationFailure.unauthenticated;
    if (user.id != id || user.appMetadata['role'] != 'advocate') {
      throw RegistrationFailure.forbidden;
    }
  }

  Future<Map<String, dynamic>?> _existing(String id) => _client
      .from('advocates')
      .select('profile_id,verification,attempts,availability')
      .eq('profile_id', id)
      .maybeSingle();

  Map<String, dynamic> _parameters(
    String userId,
    AdvocateRegistration value,
    bool isNew,
  ) => {
    'p_profile_id': userId,
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
    'p_sanad_url': value.sanadReference,
    'p_nid_url': value.nidReference,
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
    if (message.contains('max_verification_attempts_reached') ||
        message.contains('re_apply_cap_exceeded')) {
      return RegistrationFailure.attemptsExhausted;
    }
    if (message.contains('pin_guard')) return RegistrationFailure.pinProtected;
    if (message.contains('caller must')) return RegistrationFailure.forbidden;
    return RegistrationFailure.unavailable;
  }
}
