import 'dart:math';

class SosDraft {
  const SosDraft({
    required this.personName,
    required this.policeStation,
    required this.districtCourt,
    required this.contactPhone,
    this.charges = '',
    this.arrestTime,
    this.nid = '',
    this.urgency = SosUrgency.high,
    this.requestId,
    this.court = '',
  });

  final String personName;
  final String policeStation;
  final String districtCourt;
  final String contactPhone;
  final String charges;
  final DateTime? arrestTime;
  final String nid;
  final SosUrgency urgency;
  final String? requestId;
  final String court;

  static bool validPhone(String value) =>
      RegExp(r'^(?:\+880|0)1[3-9][0-9]{8}$').hasMatch(value);

  bool get isValid =>
      personName.trim().isNotEmpty &&
      policeStation.trim().isNotEmpty &&
      districtCourt.trim().isNotEmpty &&
      validPhone(contactPhone) &&
      (nid.isEmpty ||
          RegExp(r'^(?:[0-9]{10}|[0-9]{13}|[0-9]{17})$').hasMatch(nid));
}

enum SosUrgency { high, critical }

enum ClientSosStatus { open, accepted, declined, cancelled, expired }

class ClientSosRequest {
  const ClientSosRequest({
    required this.id,
    required this.district,
    required this.status,
    this.expiresAt,
    this.advocateId,
    this.isDemo = false,
  });
  final String id;
  final String district;
  final ClientSosStatus status;
  final DateTime? expiresAt;
  final String? advocateId;
  final bool isDemo;
}

enum ClientSosFailure implements Exception {
  invalid,
  unauthenticated,
  forbidden,
  rateLimited,
  unavailable,
  stateChanged,
}

String newSosRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final value = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
}

abstract class SosRepository {
  Future<ClientSosRequest> submit(SosDraft draft);
  Future<ClientSosRequest?> currentOpen() async => null;
  Stream<ClientSosRequest> watch(String id, String district) =>
      const Stream.empty();
  Future<ClientSosRequest> cancel(String id) =>
      Future.error(ClientSosFailure.unavailable);
}
