import '../../domain/entities/advocate_verification_item.dart';
import '../../domain/repositories/admin_verification_repository.dart';
import '../sources/mock_admin_verification_data_source.dart';

/// Concrete repository implementation using mock data for Sprint 1.
///
/// Implements domain's [AdminVerificationRepository].
/// Only `lib/app/di.dart` may import and bind this repository implementation.
class MockAdminVerificationRepository implements AdminVerificationRepository {
  MockAdminVerificationRepository({MockAdminVerificationDataSource? dataSource})
    : _dataSource = dataSource ?? MockAdminVerificationDataSource();

  final MockAdminVerificationDataSource _dataSource;

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
  Future<void> updateStatus(String id, VerificationStatus status) async {
    // Simulated network write latency
    await Future.delayed(const Duration(milliseconds: 600));
    _dataSource.updateStatus(id, status);
  }

  @override
  Future<void> refresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
  }
}
