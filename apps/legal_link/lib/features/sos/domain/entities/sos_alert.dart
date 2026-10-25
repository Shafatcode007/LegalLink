/// An SOS as advocates see it in the live district feed (TRD §5.4 sos_requests).
class SosAlert {
  const SosAlert({
    required this.id,
    required this.district,
    required this.thana,
    required this.status,
    this.court,
    this.urgency,
    this.createdAt,
  });

  final String id;
  final String district;
  final String thana;
  final String status;
  final String? court;
  final String? urgency;
  final DateTime? createdAt;
}

enum SosChangeType { inserted, updated }

class SosChange {
  const SosChange(this.type, this.alert);

  final SosChangeType type;
  final SosAlert alert;
}
