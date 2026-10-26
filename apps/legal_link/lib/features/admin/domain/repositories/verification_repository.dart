import '../entities/advocate_verification_item.dart';

abstract interface class VerificationRepository {
  Future<List<AdvocateVerificationItem>> getAll();
  Future<void> approve(String id);
  Future<void> reject(String id, {String? reason});
  Future<void> refresh();
  AdvocateVerificationItem? getById(String id);
}
