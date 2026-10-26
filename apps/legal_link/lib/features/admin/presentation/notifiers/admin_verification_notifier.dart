/// Legacy compatibility shim for Sprint 1 admin imports.
///
/// Canonical implementation lives in `providers/admin_verification_provider.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/verification_repository.dart';

export '../providers/admin_verification_provider.dart';

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  throw StateError('VerificationRepository must be overridden in app/di.dart');
});
