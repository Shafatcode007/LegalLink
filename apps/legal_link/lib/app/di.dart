import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' show Override;

import '../features/admin/data/repositories/supabase_admin_verification_repository.dart';
import '../features/admin/domain/repositories/admin_verification_repository.dart';
import '../features/sos/data/repositories/supabase_sos_repository.dart';
import '../features/sos/domain/repositories/sos_repository.dart';

/// Composition Root (TRD §8.1, ADR-016).
///
/// Single exemption: Only `lib/app/di.dart` may import both `domain/` and `data/`
/// to bind concrete repository implementations via [ProviderScope] overrides.
List<Override> createDiOverrides({
  AdminVerificationRepository? adminVerificationRepository,
  SosRepository? sosRepository,
}) {
  return [
    adminVerificationRepositoryProvider.overrideWithValue(
      adminVerificationRepository ?? SupabaseAdminVerificationRepository(),
    ),
    sosRepositoryProvider.overrideWithValue(
      sosRepository ?? SupabaseSosRepository(),
    ),
  ];
}

/// Helper wrapper to wrap the application or test root with composition-bound [ProviderScope].
Widget withDependencyInjection({
  required Widget child,
  AdminVerificationRepository? adminVerificationRepository,
  SosRepository? sosRepository,
}) {
  return ProviderScope(
    overrides: createDiOverrides(
      adminVerificationRepository: adminVerificationRepository,
      sosRepository: sosRepository,
    ),
    child: child,
  );
}
