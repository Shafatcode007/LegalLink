import 'case_creation_result.dart';
import 'sos_request_item.dart';

export 'case_creation_result.dart';

/// Pure Dart result of an advocate's accept action on an SOS request (TRD §5.4, §8.1).
///
/// Implements the 3 outcomes:
/// 1. [SosAcceptSuccess]: The advocate won the race. Case was created.
/// 2. [SosAcceptAlreadyTaken]: Backend returned `null` (row lock lost to another advocate).
/// 3. [SosAcceptFailure]: Network error or permission failure.
sealed class SosAcceptResult {
  const SosAcceptResult();
}

/// Advocate successfully accepted the SOS; backend returned the row and created the case.
/// Also implements [CaseCreationResult] per Sprint 2 spec.
class SosAcceptSuccess extends SosAcceptResult implements CaseCreationResult {
  const SosAcceptSuccess({
    required this.sosRequest,
    required this.caseId,
    this.caseNumber,
    this.createdAt,
  });

  final SosRequestItem sosRequest;

  @override
  final String caseId;

  @override
  final String? caseNumber;

  @override
  final DateTime? createdAt;

  @override
  String get sosId => sosRequest.id;

  @override
  String? get clientName => sosRequest.personName;

  @override
  String? get thana => sosRequest.thana;

  @override
  String? get district => sosRequest.district;

  @override
  String? get court => sosRequest.court;

  @override
  String? get contactPhone => sosRequest.contactPhone;
}

/// Another advocate accepted first; backend `accept_sos` returned `null`.
/// Triggers the "This SOS is already taken" UI state without action buttons.
class SosAcceptAlreadyTaken extends SosAcceptResult {
  const SosAcceptAlreadyTaken({
    required this.sosId,
    this.message = 'এই SOS ইতিমধ্যে অন্য একজন আইনজীবী গ্রহণ করেছেন (This SOS is already taken)',
  });

  final String sosId;
  final String message;
}

/// Generic failure (network, authentication, etc.)
class SosAcceptFailure extends SosAcceptResult {
  const SosAcceptFailure({required this.message});

  final String message;
}
