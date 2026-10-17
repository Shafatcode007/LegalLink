import 'package:riverpod/riverpod.dart';

import '../entities/advocate_verification_item.dart';

/// Pure Dart repository interface for Admin Verification (Role B2).
///
/// Adheres strictly to TRD §8.1:
/// - Pure Dart: no flutter, supabase_flutter, hive, data/, or presentation/ imports.
/// - Pure riverpod package is allowed for provider tokens.
abstract class AdminVerificationRepository {
  /// Provides immediate synchronous cached/seed items for state initialization.
  List<AdvocateVerificationItem> getCachedAdvocates();

  /// Fetches advocates for verification queue asynchronously.
  Future<List<AdvocateVerificationItem>> getAdvocates();

  /// Retrieves an advocate by ID.
  Future<AdvocateVerificationItem?> getById(String id);

  /// Updates verification status (approved / rejected).
  Future<void> updateStatus(String id, VerificationStatus status);

  /// Refreshes data from backend source.
  Future<void> refresh();
}

/// Abstract provider token declared in the feature's domain layer (TRD §8.1).
///
/// Concrete bindings are registered ONLY via ProviderScope overrides in `lib/app/di.dart`.
final adminVerificationRepositoryProvider =
    Provider<AdminVerificationRepository>((ref) {
      throw UnimplementedError(
        'adminVerificationRepositoryProvider must be overridden in lib/app/di.dart',
      );
    });
