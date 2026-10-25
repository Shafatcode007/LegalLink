import '../../domain/entities/sos_request_item.dart';

/// DTO mapping Supabase `sos_requests` JSON wire format (snake_case) to domain entity.
class SosRequestDto {
  static SosRequestItem fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String? ?? 'open';
    final SosStatus status;
    switch (rawStatus) {
      case 'accepted':
        status = SosStatus.accepted;
        break;
      case 'cancelled':
        status = SosStatus.cancelled;
        break;
      case 'expired':
        status = SosStatus.expired;
        break;
      case 'open':
      default:
        status = SosStatus.open;
        break;
    }

    final rawUrgency = json['urgency'] as String? ?? 'high';
    final SosUrgency urgency;
    switch (rawUrgency) {
      case 'critical':
        urgency = SosUrgency.critical;
        break;
      case 'medium':
        urgency = SosUrgency.medium;
        break;
      case 'high':
      default:
        urgency = SosUrgency.high;
        break;
    }

    return SosRequestItem(
      id: json['id'] as String,
      clientId: json['client_id'] as String? ?? '',
      personName: json['person_name'] as String? ?? 'আটককৃত ব্যক্তি (Arrestee)',
      thana: json['thana'] as String? ?? 'ধানমন্ডি থানা (Dhanmondi Thana)',
      district: json['district'] as String? ?? 'ঢাকা (Dhaka)',
      court: json['court'] as String? ?? 'ঢাকা মহানগর দায়রা জজ আদালত',
      charges: json['charges'] as String? ?? 'ফৌজদারি মামলা / রিমান্ড আবেদন',
      arrestedAt: json['arrested_at'] != null
          ? DateTime.tryParse(json['arrested_at'].toString())
          : null,
      personNid: json['person_nid'] as String?,
      urgency: urgency,
      contactPhone: json['contact_phone'] as String? ?? '+880 1700-000000',
      notes: json['notes'] as String?,
      status: status,
      advocateId: json['advocate_id'] as String?,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.tryParse(json['accepted_at'].toString())
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 2.4,
    );
  }

  static Map<String, dynamic> toJson(SosRequestItem item) {
    return {
      'id': item.id,
      'client_id': item.clientId,
      'person_name': item.personName,
      'thana': item.thana,
      'district': item.district,
      'court': item.court,
      'charges': item.charges,
      if (item.arrestedAt != null)
        'arrested_at': item.arrestedAt!.toIso8601String(),
      if (item.personNid != null) 'person_nid': item.personNid,
      'urgency': item.urgency.name,
      'contact_phone': item.contactPhone,
      if (item.notes != null) 'notes': item.notes,
      'status': item.status.name,
      if (item.advocateId != null) 'advocate_id': item.advocateId,
    };
  }
}
