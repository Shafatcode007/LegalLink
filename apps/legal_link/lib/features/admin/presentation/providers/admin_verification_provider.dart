import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/advocate_verification_item.dart';
import '../../domain/repositories/admin_verification_repository.dart';

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

  AdminVerificationState copyWith({
    List<AdvocateVerificationItem>? items,
    bool? isLoading,
    VerificationStatus? filter,
    bool clearFilter = false,
    String? errorMessage,
  }) {
    return AdminVerificationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      filter: clearFilter ? null : (filter ?? this.filter),
      errorMessage: errorMessage ?? this.errorMessage,
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
    state = state.copyWith(isLoading: true);
    try {
      await _repository.updateStatus(id, VerificationStatus.approved);
      final updated = await _repository.getAdvocates();
      state = state.copyWith(items: updated, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Reject advocate and update through repository
  Future<void> reject(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.updateStatus(id, VerificationStatus.rejected);
      final updated = await _repository.getAdvocates();
      state = state.copyWith(items: updated, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Refreshes data from repository with loading state
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.refresh();
      final updated = await _repository.getAdvocates();
      state = state.copyWith(items: updated, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
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
