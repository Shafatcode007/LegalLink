import '../domain/entities/sos_alert.dart';

/// Maps a `sos_requests` row from a Realtime payload to [SosAlert].
SosAlert sosAlertFromRecord(Map<String, dynamic> row) {
  final id = row['id'];
  final district = row['district'];
  if (id is! String || district is! String) {
    throw FormatException('sos_requests row needs id and district', row);
  }

  final createdAt = row['created_at'];
  return SosAlert(
    id: id,
    district: district,
    thana: row['thana'] as String? ?? '',
    status: row['status'] as String? ?? 'open',
    court: row['court'] as String?,
    urgency: row['urgency'] as String?,
    createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
  );
}
