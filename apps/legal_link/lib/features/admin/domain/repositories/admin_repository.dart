import 'package:riverpod/riverpod.dart';

import '../entities/advocate_verification_item.dart';

/// Pure Dart domain repository interface for Admin operations (Sprint 2, Role B2).
///
/// Adheres strictly to TRD §8.1 Clean Architecture rules:
/// Pure Dart: No flutter/material.dart, supabase_flutter, hive, data/, or presentation/ imports.
abstract class AdminRepository {
  /// Fetches pending advocate verification requests.
  Future<List<AdvocateVerificationItem>> getPendingVerifications();

  /// Generates a temporary secure signed URL (15-min expiry) for document review via Supabase Storage.
  Future<String> getDocumentSignedUrl(String storagePath);

  /// Updates verification status (approved / rejected) for the specified advocate.
  Future<void> updateVerificationStatus({
    required String advocateId,
    required bool approved,
  });
}

/// Abstract provider token declared in domain layer (TRD §8.1).
///
/// Concrete bindings are provided ONLY in `lib/app/di.dart`.
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  throw UnimplementedError(
    'adminRepositoryProvider must be overridden in lib/app/di.dart',
  );
});
