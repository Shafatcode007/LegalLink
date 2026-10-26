/// Composition root for LegalLink.
///
/// Per TRD ADR-016, this is the single layer-rule exemption: it is the only
/// file permitted to bridge presentation/ and data/.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/admin/data/admin_verification_repository.dart';
import '../features/admin/data/mock_admin_verification_repository.dart';
import '../features/admin/data/repositories/supabase_admin_verification_repository.dart';
import '../features/admin/data/repositories/verification_repository_impl.dart';
import '../features/admin/domain/repositories/admin_verification_repository.dart';
import '../features/auth/data/mock_auth_repository.dart';
import '../features/auth/presentation/providers/auth_controller.dart';
import '../features/sos/data/repositories/supabase_sos_repository.dart';
import '../features/sos/domain/repositories/sos_repository.dart';
import '../features/triage/data/template_ai_service.dart';
import '../features/triage/presentation/providers/ai_service_provider.dart';

export '../features/admin/presentation/notifiers/admin_verification_notifier.dart';
export '../features/admin/presentation/providers/admin_verification_provider.dart';

/// Provider factory for AdminVerificationRepository.
/// Defaults to mock implementation; override via createDiOverrides() for runtime.
final adminVerificationRepositoryProvider = Provider<
  AdminVerificationRepository
>((ref) => MockAdminVerificationRepository());

/// Provider factory for AuthRepository.
final authRepositoryProvider = Provider<
  MockAuthRepository
>((ref) => MockAuthRepository(Hive.box<dynamic>('auth_box')));

/// Provider factory for SOSRepository.
final sosRepositoryProvider = Provider<
  SosRepository
>((ref) => SupabaseSosRepository());

/// Provider factory for VerificationRepository.
final verificationRepositoryProvider = Provider<
  VerificationRepositoryImpl
>((ref) => VerificationRepositoryImpl());

/// Provider factory for AI service.
final aiServiceProvider = Provider<
  TemplateAIService
>((ref) => TemplateAIService());

/// Composition-bound overrides factory for dependency injection.
List<Override> createDiOverrides({
  AdminVerificationRepository? adminVerificationRepository,
  SosRepository? sosRepository,
}) {
  final overrides = <Override>[
    authRepositoryProvider.overrideWith(
      (ref) => MockAuthRepository(Hive.box<dynamic>('auth_box')),
    ),
  ];

  if (adminVerificationRepository != null) {
    overrides.add(
      adminVerificationRepositoryProvider.overrideWithValue(
        adminVerificationRepository,
      ),
    );
  }

  if (sosRepository != null) {
    overrides.add(
      sosRepositoryProvider.overrideWithValue(sosRepository),
    );
  }

  return overrides;
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

class AppDependencyScope extends StatelessWidget {
  const AppDependencyScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWith(
          (ref) => MockAuthRepository(Hive.box<dynamic>('auth_box')),
        ),
      ],
      child: child,
    );
  }
}
