/// Composition root for LegalLink (TRD §8.1, ADR-016).
///
/// Per TRD ADR-016, this is the single layer-rule exemption: it is the only
/// file permitted to bridge presentation/ and data/.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/admin/data/repositories/supabase_admin_verification_repository.dart';
import '../features/admin/data/repositories/verification_repository_impl.dart';
import '../features/admin/domain/repositories/admin_verification_repository.dart';
import '../features/admin/presentation/notifiers/admin_verification_notifier.dart';
import '../features/auth/data/mock_auth_repository.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/auth/presentation/providers/auth_controller.dart';
import '../features/sos/data/repositories/supabase_sos_repository.dart';
import '../features/sos/domain/repositories/sos_repository.dart';
import '../features/triage/data/template_ai_service.dart';
import '../features/triage/presentation/providers/ai_service_provider.dart';
import '../core/app_mode.dart';
import '../features/onboarding/data/local_onboarding_repositories.dart';
import '../features/onboarding/data/supabase_advocate_registration_repository.dart';
import '../features/onboarding/data/supabase_credential_upload_repository.dart';
import '../features/sos/data/supabase_client_sos_repository.dart';
import '../features/onboarding/domain/onboarding_providers.dart';
import '../features/sos/data/local_sos_repository.dart';
import '../features/sos/domain/sos_providers.dart' as client_sos;
import 'config.dart';

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

  static Future<void> initializeBackend() async {
    if (!AppConfig.useSupabaseAuth) return;
    if (AppConfig.supabaseUrl.isEmpty || AppConfig.supabaseAnonKey.isEmpty) {
      throw StateError('Live auth requires SUPABASE_URL and SUPABASE_ANON_KEY');
    }
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      ...createDiOverrides(),
      ..._authOverrides(),
      ..._onboardingOverrides(),
    ],
    child: child,
  );
}

List<Override> _authOverrides() => [
  appModeProvider.overrideWithValue(
    AppConfig.useSupabaseAuth ? AppMode.live : AppMode.demo,
  ),
  authRepositoryProvider.overrideWith(
    (ref) => AppConfig.useSupabaseAuth
        ? SupabaseAuthRepository(Supabase.instance.client)
        : MockAuthRepository(Hive.box<dynamic>('auth_box')),
  ),
  client_sos.sosRepositoryProvider.overrideWith(
    (ref) => AppConfig.useSupabaseAuth
        ? SupabaseClientSosRepository(Supabase.instance.client)
        : LocalSosRepository(),
  ),
];

List<Override> _onboardingOverrides() => [
  credentialPickerProvider.overrideWithValue(PlatformCredentialPicker()),
  credentialUploadRepositoryProvider.overrideWith((ref) {
    if (!AppConfig.useSupabaseAuth) return LocalCredentialUploadRepository();
    final repository = SupabaseCredentialUploadRepository(
      Supabase.instance.client,
      endpoint: Uri.parse(
        '${AppConfig.supabaseUrl}/storage/v1/upload/resumable',
      ),
    );
    ref.onDispose(repository.dispose);
    return repository;
  }),
  advocateRegistrationRepositoryProvider.overrideWith(
    (ref) => AppConfig.useSupabaseAuth
        ? SupabaseAdvocateRegistrationRepository(Supabase.instance.client)
        : LocalAdvocateRegistrationRepository(),
  ),
];
