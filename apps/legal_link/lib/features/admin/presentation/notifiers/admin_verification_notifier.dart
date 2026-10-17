/// Riverpod notifier for the admin verification queue.
///
/// Depends on [VerificationRepository] (data layer) — the only cross-layer
/// dependency, injected via [di.dart].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/advocate_verification_item.dart';
import '../../data/repositories/verification_repository_impl.dart';

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
      items.where((item) => item.status.isPending).length;

  int get approvedCount =>
      items.where((item) => item.status.isApproved).length;

  int get rejectedCount =>
      items.where((item) => item.status.isRejected).length;

  AdminVerificationState copyWith({
    List<AdvocateVerificationItem>? items,
    bool? isLoading,
    VerificationStatus? filter,
    String? errorMessage,
  }) {
    return AdminVerificationState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      filter: filter,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Modern Riverpod 3.x Notifier for managing admin verification operations.
class AdminVerificationNotifier extends Notifier<AdminVerificationState> {
  late final VerificationRepository _repository;

  @override
  AdminVerificationState build() {
    _repository = VerificationRepositoryImpl();
    return AdminVerificationState(items: const []);
  }

  /// Load items from the repository.
  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final items = await _repository.getAll();
    state = state.copyWith(items: items, isLoading: false);
  }

  /// Filter items by status (null = show all)
  void setFilter(VerificationStatus? filter) {
    state = state.copyWith(filter: filter);
  }

  /// Approve advocate and transition state to approved
  Future<void> approve(String id) async {
    state = state.copyWith(isLoading: true);
    await _repository.approve(id);
    final items = await _repository.getAll();
    state = state.copyWith(items: items, isLoading: false);
  }

  /// Reject advocate and transition state to rejected
  Future<void> reject(String id, {String? reason}) async {
    state = state.copyWith(isLoading: true);
    await _repository.reject(id, reason: reason);
    final items = await _repository.getAll();
    state = state.copyWith(items: items, isLoading: false);
  }

  /// Simulates refreshing data from backend with custom loading metaphor
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _repository.refresh();
    final items = await _repository.getAll();
    state = state.copyWith(items: items, isLoading: false);
  }

  /// Retrieve a single advocate by ID
  AdvocateVerificationItem? getById(String id) {
    return _repository.getById(id);
  }
}

/// Provider instance for the admin verification queue
final adminVerificationProvider =
    NotifierProvider<AdminVerificationNotifier, AdminVerificationState>(
      AdminVerificationNotifier.new,
    );
