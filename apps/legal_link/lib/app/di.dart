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
import '../features/auth/data/mock_auth_repository.dart';
import '../features/auth/presentation/providers/auth_controller.dart';

export '../features/admin/presentation/notifiers/admin_verification_notifier.dart';

/// Provider factory for AdminVerificationRepository.
final adminVerificationRepositoryProvider = Provider<
  AdminVerificationRepository
>((ref) => MockAdminVerificationRepository());

/// Provider factory for AuthRepository.
final authRepositoryProvider = Provider<
  MockAuthRepository
>((ref) => MockAuthRepository(Hive.box<dynamic>('auth_box')));

/// Composition-bound overrides factory for dependency injection.
List<Override> createDiOverrides({
  AdminVerificationRepository? adminVerificationRepository,
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

  return overrides;
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
