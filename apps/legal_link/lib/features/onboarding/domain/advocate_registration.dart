enum Specialization { criminal, bail, family, property, labor, womenAndChild }

class AdvocateRegistration {
  const AdvocateRegistration({
    required this.nid,
    required this.barCouncilNumber,
    required this.courts,
    required this.specializations,
    required this.feeMin,
    required this.feeMax,
    required this.languages,
    required this.sanadReference,
    required this.nidReference,
    this.districts = const [],
    this.pin = '',
    this.yearsPractice = 0,
    this.availableForSos = true,
    this.avatarReference,
  });

  final String nid;
  final String barCouncilNumber;
  final List<String> courts;
  final Set<Specialization> specializations;
  final int feeMin;
  final int feeMax;
  final Set<String> languages;
  final String sanadReference;
  final String nidReference;
  final List<String> districts;
  final String pin;
  final int yearsPractice;
  final bool availableForSos;
  final String? avatarReference;

  static bool validNid(String value) =>
      RegExp(r'^(?:[0-9]{10}|[0-9]{13}|[0-9]{17})$').hasMatch(value);

  bool get isValid =>
      validNid(nid) &&
      barCouncilNumber.trim().isNotEmpty &&
      courts.isNotEmpty &&
      courts.every((court) => court.trim().isNotEmpty) &&
      districts.isNotEmpty &&
      districts.every((district) => district.trim().isNotEmpty) &&
      specializations.isNotEmpty &&
      feeMin >= 0 &&
      feeMax >= feeMin &&
      feeMax <= 9999999999 &&
      yearsPractice >= 0 &&
      yearsPractice <= 80 &&
      validPin &&
      languages.isNotEmpty &&
      languages.every((language) => {'bn', 'en'}.contains(language)) &&
      sanadReference.isNotEmpty &&
      nidReference.isNotEmpty;
  bool get validPin => pin.isEmpty || RegExp(r'^[0-9]{4}$').hasMatch(pin);
}

enum RegistrationFailure implements Exception {
  invalid,
  unauthenticated,
  forbidden,
  attemptsExhausted,
  pinProtected,
  unavailable,
}

abstract interface class AdvocateRegistrationRepository {
  Future<void> submit(String userId, AdvocateRegistration registration);
}
