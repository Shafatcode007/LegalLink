/// Pure Dart domain entity for SOS Request (TRD §5.4, §8.1).
///
/// Adheres strictly to Clean Architecture rules:
/// Pure Dart: No flutter, supabase_flutter, hive, data/, or presentation/ imports.
library;

enum SosUrgency {
  high('জরুরি (High)'),
  critical('মারাত্মক জরুরি (Critical)'),
  medium('সাধারণ (Medium)');

  const SosUrgency(this.label);
  final String label;
}

enum SosStatus {
  open('চলমান (Live)'),
  accepted('গৃহীত (Accepted)'),
  cancelled('বাতিল (Cancelled)'),
  expired('সময় শেষ (Expired)');

  const SosStatus(this.label);
  final String label;

  bool get isOpen => this == SosStatus.open;
  bool get isAccepted => this == SosStatus.accepted;
  bool get isExpired => this == SosStatus.expired;
  bool get isCancelled => this == SosStatus.cancelled;
}

/// Represents an emergency SOS request broadcast to nearby verified advocates.
class SosRequestItem {
  const SosRequestItem({
    required this.id,
    required this.clientId,
    required this.personName,
    required this.thana,
    required this.district,
    this.court = 'ঢাকা জেলা জজ আদালত',
    this.charges = 'ফৌজদারি মামলা / রিমান্ড আবেদন',
    this.arrestedAt,
    this.personNid,
    this.urgency = SosUrgency.high,
    required this.contactPhone,
    this.notes,
    this.status = SosStatus.open,
    this.advocateId,
    this.acceptedAt,
    this.expiresAt,
    this.createdAt,
    this.isQueuedLocally = false,
    this.distanceKm = 2.4,
  });

  final String id;
  final String clientId;
  final String personName;
  final String thana;
  final String district;
  final String court;
  final String charges;
  final DateTime? arrestedAt;
  final String? personNid;
  final SosUrgency urgency;
  final String contactPhone;
  final String? notes;
  final SosStatus status;
  final String? advocateId;
  final DateTime? acceptedAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final bool isQueuedLocally;
  final double distanceKm;

  bool get isExpired =>
      status.isExpired ||
      (expiresAt != null && expiresAt!.isBefore(DateTime.now()));

  SosRequestItem copyWith({
    String? id,
    String? clientId,
    String? personName,
    String? thana,
    String? district,
    String? court,
    String? charges,
    DateTime? arrestedAt,
    String? personNid,
    SosUrgency? urgency,
    String? contactPhone,
    String? notes,
    SosStatus? status,
    String? advocateId,
    DateTime? acceptedAt,
    DateTime? expiresAt,
    DateTime? createdAt,
    bool? isQueuedLocally,
    double? distanceKm,
  }) {
    return SosRequestItem(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      personName: personName ?? this.personName,
      thana: thana ?? this.thana,
      district: district ?? this.district,
      court: court ?? this.court,
      charges: charges ?? this.charges,
      arrestedAt: arrestedAt ?? this.arrestedAt,
      personNid: personNid ?? this.personNid,
      urgency: urgency ?? this.urgency,
      contactPhone: contactPhone ?? this.contactPhone,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      advocateId: advocateId ?? this.advocateId,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      isQueuedLocally: isQueuedLocally ?? this.isQueuedLocally,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }
}
