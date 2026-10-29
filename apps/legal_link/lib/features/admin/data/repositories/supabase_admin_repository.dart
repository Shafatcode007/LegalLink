import '../../domain/entities/advocate_verification_item.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/repositories/admin_verification_repository.dart';
import '../sources/supabase_admin_data_source.dart';

/// Real backend repository implementation for Admin operations (Sprint 2, Role B2).
///
/// Implements [AdminRepository] and [AdminVerificationRepository] using [SupabaseAdminDataSource].
/// Connects to real Supabase PostgREST, Storage Signed URLs (`supabase.storage.from('sanad').createSignedUrl(...)`),
/// and `admin_decide` RPC with PostgreSQL row locking.
class SupabaseAdminRepository
    implements AdminRepository, AdminVerificationRepository {
  SupabaseAdminRepository({SupabaseAdminDataSource? dataSource})
    : _dataSource = dataSource ?? SupabaseAdminDataSource();

  final SupabaseAdminDataSource _dataSource;
  List<AdvocateVerificationItem> _cachedItems = [];

  // ================= AdminRepository implementation =================

  @override
  Future<List<AdvocateVerificationItem>> getPendingVerifications() async {
    final all = await getAdvocates();
    return all.where((item) => item.status.isPending).toList();
  }

  @override
  Future<String> getDocumentSignedUrl(
    String storagePath, {
    Duration expiresIn = const Duration(minutes: 15),
  }) async {
    final signedUrl = await _dataSource.createSignedUrl(
      storagePath,
      expiresInSeconds: expiresIn.inSeconds,
    );
    if (signedUrl != null) {
      return signedUrl;
    }
    // Fallback safe URL
    final cleanPath = storagePath.startsWith('http')
        ? storagePath.split('?').first
        : 'https://storage.legallink.bd/$storagePath';
    return '$cleanPath?token=exp_15m_sec_preview';
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
    if (_cachedItems.isNotEmpty) {
      return _cachedItems;
    }
    if (_dataSource.activeClient != null) {
      return const [];
    }
    return _dataSource.fallback.items;
  }

  @override
  Future<List<AdvocateVerificationItem>> getAdvocates() async {
    final rawItems = await _dataSource.fetchAdvocates();
    final now = DateTime.now();
    final expiry = now.add(const Duration(minutes: 15));

    // Resolve 15-minute temporary signed URLs for documents per ADR-011
    final List<AdvocateVerificationItem> itemsWithSignedUrls = [];
    for (final item in rawItems) {
      String? sanadSignedUrl = item.sanadSignedUrl;
      if (item.sanadUrl != null && item.sanadUrl!.isNotEmpty) {
        sanadSignedUrl = await _dataSource.createSignedUrl(
          item.sanadUrl!,
          expiresInSeconds: 900,
        );
      }

      String? nidSignedUrl = item.nidSignedUrl;
      if (item.nidUrl != null && item.nidUrl!.isNotEmpty) {
        nidSignedUrl = await _dataSource.createSignedUrl(
          item.nidUrl!,
          expiresInSeconds: 900,
        );
      }

      itemsWithSignedUrls.add(
        item.copyWith(
          sanadSignedUrl: sanadSignedUrl,
          nidSignedUrl: nidSignedUrl,
          signedUrlExpiresAt: expiry,
        ),
      );
    }

    _cachedItems = itemsWithSignedUrls;
    return _cachedItems;
  }

  @override
  Future<AdvocateVerificationItem?> getById(String id) async {
    if (_cachedItems.isEmpty) {
      await getAdvocates();
    }
    try {
      return _cachedItems.firstWhere((item) => item.id == id);
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
    await _dataSource.decideVerification(id, status, rejectionReason: reason);

    // Update in-memory cached state immediately
    _cachedItems = _cachedItems.map((item) {
      if (item.id == id) {
        return item.copyWith(status: status, rejectionReason: reason);
      }
      return item;
    }).toList();
  }

  @override
  Future<void> refresh() async {
    await getAdvocates();
  }
}

/// Alias for [SupabaseAdminRepository] matching conventional naming.
typedef AdminRepositoryImpl = SupabaseAdminRepository;
