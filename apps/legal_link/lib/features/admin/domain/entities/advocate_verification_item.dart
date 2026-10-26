// ignore_for_file: prefer_initializing_formals

/// Pure Dart domain entity for Advocate Verification (Role B2).
///
/// Adheres strictly to TRD §8.1 Clean Architecture rules:
/// No Flutter, Hive, Supabase, data/, or presentation/ imports.
library;

enum VerificationStatus {
  pending('অপেক্ষমান (Pending)'),
  approved('অনুমোদিত (Approved)'),
  rejected('প্রত্যাখ্যাত (Rejected)');

  const VerificationStatus(this.label);
  final String label;

  bool get isPending => this == VerificationStatus.pending;
  bool get isApproved => this == VerificationStatus.approved;
  bool get isRejected => this == VerificationStatus.rejected;
}

/// Entity representing an advocate in the verification queue.
class AdvocateVerificationItem {
  const AdvocateVerificationItem({
    required this.id,
    required this.fullName,
    required this.barCouncilNo,
    String? courtDivision,
    String? sanadDocUrl,
    String? sanadUrl,
    this.sanadSignedUrl,
    this.phone = '+880 1711-000000',
    this.nidNumber,
    this.nidUrl,
    this.nidSignedUrl,
    this.signedUrlExpiresAt,
    this.yearsOfExperience = 8,
    String? specialization,
    List<String>? specializations,
    List<String>? courts,
    this.districts = const [],
    this.languages = const ['bn'],
    this.feeMinBdt,
    this.feeMaxBdt,
    this.status = VerificationStatus.pending,
    this.rejectionReason,
    this.submittedAt,
  }) : _courtDivision = courtDivision,
       _sanadDocUrl = sanadDocUrl,
       _sanadUrl = sanadUrl,
       _specialization = specialization,
       _specializations = specializations,
       _courts = courts;

  final String id;
  final String fullName;
  final String barCouncilNo;
  final String? _courtDivision;
  final String? _sanadDocUrl;
  final String? _sanadUrl;
  final String? sanadSignedUrl;
  final String phone;
  final String? nidNumber;
  final String? nidUrl;
  final String? nidSignedUrl;
  final DateTime? signedUrlExpiresAt;
  final int yearsOfExperience;
  final String? _specialization;
  final List<String>? _specializations;
  final List<String>? _courts;
  final List<String> districts;
  final List<String> languages;
  final double? feeMinBdt;
  final double? feeMaxBdt;
  final VerificationStatus status;
  final String? rejectionReason;
  final DateTime? submittedAt;

  String get courtDivision =>
      _courtDivision ??
      (_courts != null && _courts.isNotEmpty ? _courts.first : '');

  List<String> get courts =>
      _courts ??
      (_courtDivision != null && _courtDivision.isNotEmpty
          ? [_courtDivision]
          : const []);

  String? get sanadUrl => _sanadUrl ?? _sanadDocUrl;
  String? get sanadDocUrl => _sanadDocUrl ?? _sanadUrl;

  /// Effective URL for preview (prefers temporary secure signed URL per TRD ADR-011)
  String? get effectiveSanadUrl => sanadSignedUrl ?? sanadUrl;

  /// Whether current signed URL is within valid 15-minute window
  bool get isSignedUrlValid =>
      signedUrlExpiresAt != null && signedUrlExpiresAt!.isAfter(DateTime.now());

  String get specialization =>
      _specialization ??
      (_specializations != null && _specializations.isNotEmpty
          ? _specializations.first
          : 'ফৌজদারি ও জামিন (Criminal & Bail)');

  List<String> get specializations =>
      _specializations ??
      (_specialization != null && _specialization.isNotEmpty
          ? [_specialization]
          : const ['ফৌজদারি ও জামিন (Criminal & Bail)']);

  AdvocateVerificationItem copyWith({
    String? id,
    String? fullName,
    String? barCouncilNo,
    String? courtDivision,
    List<String>? courts,
    String? sanadDocUrl,
    String? sanadUrl,
    String? sanadSignedUrl,
    String? phone,
    String? nidNumber,
    String? nidUrl,
    String? nidSignedUrl,
    DateTime? signedUrlExpiresAt,
    int? yearsOfExperience,
    String? specialization,
    List<String>? specializations,
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
      courtDivision: courtDivision ?? _courtDivision,
      courts: courts ?? _courts,
      sanadDocUrl: sanadDocUrl ?? _sanadDocUrl,
      sanadUrl: sanadUrl ?? _sanadUrl,
      sanadSignedUrl: sanadSignedUrl ?? this.sanadSignedUrl,
      phone: phone ?? this.phone,
      nidNumber: nidNumber ?? this.nidNumber,
      nidUrl: nidUrl ?? this.nidUrl,
      nidSignedUrl: nidSignedUrl ?? this.nidSignedUrl,
      signedUrlExpiresAt: signedUrlExpiresAt ?? this.signedUrlExpiresAt,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      specialization: specialization ?? _specialization,
      specializations: specializations ?? _specializations,
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
