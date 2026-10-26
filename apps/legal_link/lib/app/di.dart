/// Composition root for LegalLink (TRD §8.1, ADR-016).
///
/// Per TRD ADR-016, this is the single layer-rule exemption: it is the only
/// file permitted to bridge presentation/ and data/.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' show Override;

import '../features/admin/data/repositories/supabase_admin_verification_repository.dart';
import '../features/admin/data/repositories/verification_repository_impl.dart';
import '../features/admin/domain/repositories/admin_verification_repository.dart';
import '../features/admin/presentation/notifiers/admin_verification_notifier.dart';
import '../features/auth/data/mock_auth_repository.dart';
import '../features/auth/presentation/providers/auth_controller.dart';
import '../features/sos/data/repositories/supabase_sos_repository.dart';
import '../features/sos/domain/repositories/sos_repository.dart';
import '../features/triage/data/template_ai_service.dart';
import '../features/triage/presentation/providers/ai_service_provider.dart';

export '../features/admin/presentation/providers/admin_verification_provider.dart';

/// Composition Root overrides factory.
List<Override> createDiOverrides({
  AdminVerificationRepository? adminVerificationRepository,
  SosRepository? sosRepository,
}) {
  return [
    adminVerificationRepositoryProvider.overrideWith(
      (ref) =>
          adminVerificationRepository ?? SupabaseAdminVerificationRepository(),
    ),
    sosRepositoryProvider.overrideWith(
      (ref) => sosRepository ?? SupabaseSosRepository(),
    ),
    verificationRepositoryProvider.overrideWith(
      (ref) => VerificationRepositoryImpl(),
    ),
    aiServiceProvider.overrideWith((ref) => TemplateAIService()),
  ];
}

/// Bindings shared by the app and the admin smoke surface.
final appOverrides = createDiOverrides();

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

class AppDependencyScope extends StatelessWidget {
  const AppDependencyScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        ...createDiOverrides(),
        authRepositoryProvider.overrideWith((ref) {
          final box = Hive.box<dynamic>('auth_box');
          return MockAuthRepository(box);
        }),
      ],
      child: child,
    );
  }
}
