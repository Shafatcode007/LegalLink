import 'advocate_registration.dart';

enum AdvocateVerification { pending, verified, rejected }

class AdvocateApplication {
  const AdvocateApplication({
    required this.registration,
    required this.verification,
    this.rejectionReason,
    this.attempts = 0,
    this.isDemo = false,
  });

  final AdvocateRegistration registration;
  final AdvocateVerification verification;
  final String? rejectionReason;
  final int attempts;
  final bool isDemo;

  bool get isVerified => verification == AdvocateVerification.verified;
  bool get canResubmit => !isVerified && attempts < 3;
}
