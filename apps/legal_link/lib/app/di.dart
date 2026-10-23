/// Composition root for LegalLink.
///
/// Per TRD ADR-016, this is the single layer-rule exemption: it is the only
/// file permitted to bridge presentation/ and data/.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/admin/data/repositories/verification_repository_impl.dart';
import '../features/admin/presentation/notifiers/admin_verification_notifier.dart';
import '../features/auth/data/mock_auth_repository.dart';
import '../features/auth/presentation/providers/auth_controller.dart';

export '../features/admin/presentation/notifiers/admin_verification_notifier.dart';

/// Bindings shared by the app and the admin smoke surface.
final appOverrides = [
  verificationRepositoryProvider.overrideWith(
    (ref) => VerificationRepositoryImpl(),
  ),
];

class AppDependencyScope extends StatelessWidget {
  const AppDependencyScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        ...appOverrides,
        authRepositoryProvider.overrideWith((ref) {
          final box = Hive.box<dynamic>('auth_box');
          return MockAuthRepository(box);
        }),
      ],
      child: child,
    );
  }
}
