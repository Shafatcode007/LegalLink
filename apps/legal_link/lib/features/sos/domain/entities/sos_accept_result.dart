import 'sos_request_item.dart';

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
class SosAcceptSuccess extends SosAcceptResult {
  const SosAcceptSuccess({required this.sosRequest, required this.caseId});

  final SosRequestItem sosRequest;
  final String caseId;
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
