import '../../domain/entities/advocate_verification_item.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/repositories/admin_verification_repository.dart';
import '../sources/mock_admin_verification_data_source.dart';

/// Concrete repository implementation using mock data.
///
/// Implements domain's [AdminRepository] and [AdminVerificationRepository].
/// Only `lib/app/di.dart` may import and bind this repository implementation.
class MockAdminVerificationRepository
    implements AdminRepository, AdminVerificationRepository {
  MockAdminVerificationRepository({MockAdminVerificationDataSource? dataSource})
    : _dataSource = dataSource ?? MockAdminVerificationDataSource();

  final MockAdminVerificationDataSource _dataSource;

  // ================= AdminRepository implementation =================

  @override
  Future<List<AdvocateVerificationItem>> getPendingVerifications() async {
    final all = await getAdvocates();
    return all.where((item) => item.status.isPending).toList();
  }

  @override
  Future<void> updateVerificationStatus({
    required String advocateId,
    required bool approved,
  }) async {
    await updateStatus(
      advocateId,
      approved ? VerificationStatus.approved : VerificationStatus.rejected,
    );
  }

  // ============= AdminVerificationRepository implementation =============

  @override
  List<AdvocateVerificationItem> getCachedAdvocates() {
    return _dataSource.items;
  }

  @override
  Future<List<AdvocateVerificationItem>> getAdvocates() async {
    // Simulated network latency
    await Future.delayed(const Duration(milliseconds: 300));
    return _dataSource.items;
  }

  @override
  Future<AdvocateVerificationItem?> getById(String id) async {
    try {
      return _dataSource.items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateStatus(
    String id,
    VerificationStatus status, {
    String? reason,
  }) async {
    // Simulated network write latency
    await Future.delayed(const Duration(milliseconds: 600));
    _dataSource.updateStatus(id, status, reason: reason);
  }

  @override
  Future<String> getDocumentSignedUrl(
    String storagePath, {
    Duration expiresIn = const Duration(minutes: 15),
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final cleanPath = storagePath.startsWith('http')
        ? storagePath.split('?').first
        : 'https://storage.legallink.bd/$storagePath';
    return '$cleanPath?token=exp_15m_signed_sec_preview';
  }

  @override
  Future<void> refresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
  }
}

/// Alias for MockAdminVerificationRepository matching [AdminRepository]
typedef MockAdminRepository = MockAdminVerificationRepository;
