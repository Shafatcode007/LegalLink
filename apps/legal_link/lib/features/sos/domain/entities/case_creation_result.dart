/// Pure Dart domain entity representing the result of creating a case from an SOS request.
///
/// TRD §8.1 Clean Architecture rules:
/// Pure Dart: No flutter, hive, supabase, data/, or presentation/ imports.
class CaseCreationResult {
  const CaseCreationResult({
    required this.caseId,
    required this.sosId,
    this.caseNumber,
    this.createdAt,
    this.clientName,
    this.thana,
    this.district,
    this.court,
    this.contactPhone,
  });

  /// The generated or assigned unique Case ID (e.g. 'CASE-2026-DHAKA-001')
  final String caseId;

  /// The originating SOS Request ID
  final String sosId;

  /// Optional human-readable case registration number
  final String? caseNumber;

  /// Timestamp when the case was created / accepted
  final DateTime? createdAt;

  /// Name of the client or arrested person
  final String? clientName;

  /// Location details
  final String? thana;
  final String? district;
  final String? court;

  /// Client contact phone for immediate advocate call
  final String? contactPhone;
}
