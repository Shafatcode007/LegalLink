import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' show Override;

import '../features/admin/data/repositories/mock_admin_verification_repository.dart';
import '../features/admin/domain/repositories/admin_verification_repository.dart';

/// Composition Root (TRD §8.1, ADR-016).
///
/// Single exemption: Only `lib/app/di.dart` may import both `domain/` and `data/`
/// to bind concrete repository implementations via [ProviderScope] overrides.
List<Override> createDiOverrides({
  AdminVerificationRepository? adminVerificationRepository,
}) {
  return [
    adminVerificationRepositoryProvider.overrideWithValue(
      adminVerificationRepository ?? MockAdminVerificationRepository(),
    ),
  ];
}

/// Helper wrapper to wrap the application or test root with composition-bound [ProviderScope].
Widget withDependencyInjection({
  required Widget child,
  AdminVerificationRepository? adminVerificationRepository,
}) {
  return ProviderScope(
    overrides: createDiOverrides(
      adminVerificationRepository: adminVerificationRepository,
    ),
    child: child,
  );
}
