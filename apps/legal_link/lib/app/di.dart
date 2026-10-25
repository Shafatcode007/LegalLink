/// Composition root for LegalLink.
///
/// Per TRD ADR-016, this is the single layer-rule exemption: it is the only
/// file permitted to bridge presentation/ and data/.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hive_flutter/hive_flutter.dart';

import '../core/env/app_config.dart';
import '../features/admin/data/repositories/verification_repository_impl.dart';
import '../features/admin/presentation/notifiers/admin_verification_notifier.dart';
import '../features/auth/data/mock_auth_repository.dart';
import '../features/auth/presentation/providers/auth_controller.dart';
import '../features/triage/data/template_ai_service.dart';
import '../features/triage/presentation/providers/ai_service_provider.dart';

export '../features/admin/presentation/notifiers/admin_verification_notifier.dart';

/// Bindings for [config]; Supabase-backed services bind here once they exist.
List<Override> appOverridesFor(AppConfig config) => [
  verificationRepositoryProvider.overrideWith(
    (ref) => VerificationRepositoryImpl(),
  ),
  // Swap for a Worker-backed AIService at the W4 integrate checkpoint.
  aiServiceProvider.overrideWith((ref) => TemplateAIService()),
];

/// Offline bindings shared by the app and the admin smoke surface.
final appOverrides = appOverridesFor(const AppConfig());

class AppDependencyScope extends StatelessWidget {
  const AppDependencyScope({
    required this.child,
    this.config = const AppConfig(),
    super.key,
  });

  final Widget child;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        ...appOverridesFor(config),
        authRepositoryProvider.overrideWith((ref) {
          final box = Hive.box<dynamic>('auth_box');
          return MockAuthRepository(box);
        }),
      ],
      child: child,
    );
  }
}
