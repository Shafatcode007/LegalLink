/// Composition root for LegalLink.
///
/// Per TRD ADR-016, this is the single layer-rule exemption: it is the only
/// file permitted to bridge presentation/ and data/. All other files must
/// respect the domain → data → presentation dependency direction.
library;

export '../features/admin/presentation/notifiers/admin_verification_notifier.dart';
