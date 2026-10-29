import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/admin_failure.dart';
import '../../domain/entities/advocate_verification_item.dart';
import '../../domain/repositories/admin_verification_repository.dart';

export '../../domain/entities/admin_failure.dart';
export '../../domain/entities/advocate_verification_item.dart';

/// State representation for the Admin Verification Queue.
class AdminVerificationState {
  const AdminVerificationState({
    required this.items,
    this.isLoading = false,
    this.filter,
    this.errorMessage,
  });

  final List<AdvocateVerificationItem> items;
  final bool isLoading;
  final VerificationStatus? filter;
  final String? errorMessage;

  List<AdvocateVerificationItem> get filteredItems {
    if (filter == null) return items;
    return items.where((item) => item.status == filter).toList();
  }

  int get pendingCount =>
      items.where((item) => item.status == VerificationStatus.pending).length;

  int get approvedCount =>
      items.where((item) => item.status == VerificationStatus.approved).length;

  int get rejectedCount =>
      items.where((item) => item.status == VerificationStatus.rejected).length;

  bool get hasError => errorMessage != null;

  AdminVerificationState copyWith({
    List<AdvocateVerificationItem>? items,
    bool? isLoading,
    VerificationStatus? filter,
    bool clearFilter = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminVerificationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      filter: clearFilter ? null : (filter ?? this.filter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Riverpod Notifier for managing admin verification operations.
///
/// Clean Architecture rule: Only talks to [AdminVerificationRepository] in `domain/`.
/// Never imports `data/`.
class AdminVerificationNotifier extends Notifier<AdminVerificationState> {
  late AdminVerificationRepository _repository;

  @override
  AdminVerificationState build() {
    _repository = ref.watch(adminVerificationRepositoryProvider);
    final initialItems = _repository.getCachedAdvocates();
    return AdminVerificationState(items: initialItems);
  }

  /// Loads advocates asynchronously and resolves signed URLs
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repository.getAdvocates();
      if (ref.mounted) {
        state = state.copyWith(
          items: items,
          isLoading: false,
          clearError: true,
        );
      }
    } catch (e) {
      if (ref.mounted) {
        final message = e is AdminFailure ? e.message : e.toString();
        state = state.copyWith(isLoading: false, errorMessage: message);
      }
    }
  }

  /// Filter items by status (null = show all)
  void setFilter(VerificationStatus? filter) {
    if (filter == null) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filter: filter);
    }
  }

  /// Approve advocate and update through repository
  Future<void> approve(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.updateStatus(id, VerificationStatus.approved);
      final updated = await _repository.getAdvocates();
      if (ref.mounted) {
        state = state.copyWith(
          items: updated,
          isLoading: false,
          clearError: true,
        );
      }
    } catch (e) {
      if (ref.mounted) {
        final message = e is AdminFailure ? e.message : e.toString();
        state = state.copyWith(isLoading: false, errorMessage: message);
      }
    }
  }

  /// Reject advocate and update through repository with optional reason
  Future<void> reject(String id, {String? reason}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.updateStatus(
        id,
        VerificationStatus.rejected,
        reason: reason,
      );
      final updated = await _repository.getAdvocates();
      if (ref.mounted) {
        state = state.copyWith(
          items: updated,
          isLoading: false,
          clearError: true,
        );
      }
    } catch (e) {
      if (ref.mounted) {
        final message = e is AdminFailure ? e.message : e.toString();
        state = state.copyWith(isLoading: false, errorMessage: message);
      }
    }
  }

  /// Generates or refreshes a 15-minute temporary signed URL for document preview (ADR-011)
  Future<String?> getSignedUrlFor(
    String advocateId, {
    bool isNid = false,
  }) async {
    final advocate = getById(advocateId);
    if (advocate == null) return null;
    final path = isNid ? advocate.nidUrl : advocate.sanadUrl;
    if (path == null) return null;

    final signedUrl = await _repository.getDocumentSignedUrl(path);
    if (signedUrl != null && ref.mounted) {
      final updated = advocate.copyWith(
        sanadSignedUrl: isNid ? advocate.sanadSignedUrl : signedUrl,
        nidSignedUrl: isNid ? signedUrl : advocate.nidSignedUrl,
        signedUrlExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );
      state = state.copyWith(
        items: state.items
            .map((i) => i.id == advocateId ? updated : i)
            .toList(),
      );
    }
    return signedUrl;
  }

  /// Refreshes data from repository with loading state
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.refresh();
      final updated = await _repository.getAdvocates();
      if (ref.mounted) {
        state = state.copyWith(items: updated, isLoading: false);
      }
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  /// Retrieve a single advocate by ID
  AdvocateVerificationItem? getById(String id) {
    try {
      return state.items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Provider instance for the admin verification queue
final adminVerificationProvider =
    NotifierProvider<AdminVerificationNotifier, AdminVerificationState>(
      AdminVerificationNotifier.new,
    );
