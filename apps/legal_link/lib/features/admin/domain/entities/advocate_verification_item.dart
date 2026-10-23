/// Pure-Dart domain entity for advocate verification.
///
/// Zero Flutter/UI dependencies — safe to import from domain and data layers.
enum VerificationStatus { pending, approved, rejected }

extension VerificationStatusX on VerificationStatus {
  bool get isPending => this == VerificationStatus.pending;
  bool get isApproved => this == VerificationStatus.approved;
  bool get isRejected => this == VerificationStatus.rejected;

  String get label {
    switch (this) {
      case VerificationStatus.pending:
        return 'অপেক্ষমাণ (Pending)';
      case VerificationStatus.approved:
        return 'অনুমোদিত (Approved)';
      case VerificationStatus.rejected:
        return 'প্রত্যাখ্যাত (Rejected)';
    }
  }
}

class AdvocateVerificationItem {
  final String id;
  final String fullName;
  final String barCouncilNo;
  final String? nidNumber;
  final String? sanadUrl;
  final String? nidUrl;
  final int yearsOfExperience;
  final List<String> specializations;
  final List<String> courts;
  final List<String> districts;
  final List<String> languages;
  final double? feeMinBdt;
  final double? feeMaxBdt;
  final VerificationStatus status;
  final String? rejectionReason;
  final DateTime submittedAt;

  const AdvocateVerificationItem({
    required this.id,
    required this.fullName,
    required this.barCouncilNo,
    this.nidNumber,
    this.sanadUrl,
    this.nidUrl,
    this.yearsOfExperience = 0,
    this.specializations = const [],
    this.courts = const [],
    this.districts = const [],
    this.languages = const ['bn'],
    this.feeMinBdt,
    this.feeMaxBdt,
    this.status = VerificationStatus.pending,
    this.rejectionReason,
    required this.submittedAt,
  });

  AdvocateVerificationItem copyWith({
    String? id,
    String? fullName,
    String? barCouncilNo,
    String? nidNumber,
    String? sanadUrl,
    String? nidUrl,
    int? yearsOfExperience,
    List<String>? specializations,
    List<String>? courts,
    List<String>? districts,
    List<String>? languages,
    double? feeMinBdt,
    double? feeMaxBdt,
    VerificationStatus? status,
    String? rejectionReason,
    DateTime? submittedAt,
  }) {
    return AdvocateVerificationItem(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      barCouncilNo: barCouncilNo ?? this.barCouncilNo,
      nidNumber: nidNumber ?? this.nidNumber,
      sanadUrl: sanadUrl ?? this.sanadUrl,
      nidUrl: nidUrl ?? this.nidUrl,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      specializations: specializations ?? this.specializations,
      courts: courts ?? this.courts,
      districts: districts ?? this.districts,
      languages: languages ?? this.languages,
      feeMinBdt: feeMinBdt ?? this.feeMinBdt,
      feeMaxBdt: feeMaxBdt ?? this.feeMaxBdt,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }
}
