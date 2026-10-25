import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/sos_accept_result.dart';
import '../../domain/entities/sos_request_item.dart';
import '../../domain/repositories/sos_repository.dart';

/// State representation for the Advocate SOS Inbox (Sprint 2, Role B2).
class SosInboxState {
  const SosInboxState({
    required this.items,
    this.isLoading = false,
    this.acceptingIds = const {},
    this.createdCases = const {},
    this.alreadyTakenIds = const {},
    this.errorMessage,
  });

  final List<SosRequestItem> items;
  final bool isLoading;

  /// IDs of SOS alerts currently undergoing the accept flow (UI instantly locks).
  final Set<String> acceptingIds;

  /// Map of sosId -> caseId for successfully accepted SOS alerts ("Case Created").
  final Map<String, String> createdCases;

  /// Set of sosIds that returned null from backend ("This SOS is already taken").
  final Set<String> alreadyTakenIds;

  final String? errorMessage;

  /// Whether a specific SOS alert is currently locked in the accept action.
  bool isAccepting(String sosId) => acceptingIds.contains(sosId);

  /// Whether a specific SOS alert was won and has a case created.
  bool isCaseCreated(String sosId) => createdCases.containsKey(sosId);

  /// Returns the case ID created for this SOS, if any.
  String? getCreatedCaseId(String sosId) => createdCases[sosId];

  /// Whether a specific SOS alert was lost to another advocate (backend returned null).
  bool isAlreadyTaken(String sosId) => alreadyTakenIds.contains(sosId);

  int get liveAlertsCount => items
      .where(
        (item) =>
            !alreadyTakenIds.contains(item.id) &&
            !createdCases.containsKey(item.id),
      )
      .length;

  SosInboxState copyWith({
    List<SosRequestItem>? items,
    bool? isLoading,
    Set<String>? acceptingIds,
    Map<String, String>? createdCases,
    Set<String>? alreadyTakenIds,
    String? errorMessage,
  }) {
    return SosInboxState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      acceptingIds: acceptingIds ?? this.acceptingIds,
      createdCases: createdCases ?? this.createdCases,
      alreadyTakenIds: alreadyTakenIds ?? this.alreadyTakenIds,
      errorMessage: errorMessage,
    );
  }
}

/// Riverpod Notifier managing the Advocate SOS Inbox and Single Accept Flow.
///
/// Implements:
/// - Instant UI lock when Accept is tapped
/// - Single-accept success transition -> "Case Created"
/// - Race condition transition -> "This SOS is already taken" when backend returns null
class SosInboxNotifier extends Notifier<SosInboxState> {
  late SosRepository _repository;

  @override
  SosInboxState build() {
    _repository = ref.watch(sosRepositoryProvider);
    final initialItems = _repository.getCachedInbox();
    return SosInboxState(items: initialItems);
  }

  /// Loads open alerts asynchronously from the repository.
  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await _repository.getAdvocateInbox();
      if (ref.mounted) {
        state = state.copyWith(items: items, isLoading: false);
      }
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }

  /// Advocate taps "Accept" on an SOS alert.
  ///
  /// Invariant (Task 2 & 3):
  /// 1. Instantly locks the UI for this alert (disables both Accept & Decline).
  /// 2. If won -> displays "Case Created" with case details.
  /// 3. If backend returns null -> displays "This SOS is already taken".
  Future<SosAcceptResult> accept(String sosId) async {
    // 1. Instantly lock the UI for this alert
    final updatedAccepting = Set<String>.from(state.acceptingIds)..add(sosId);
    state = state.copyWith(acceptingIds: updatedAccepting);

    try {
      final result = await _repository.acceptSos(sosId);

      if (!ref.mounted) return result;

      final clearedAccepting = Set<String>.from(state.acceptingIds)
        ..remove(sosId);

      switch (result) {
        case SosAcceptSuccess(:final caseId):
          // Won the race! Display "Case Created"
          final updatedCases = Map<String, String>.from(state.createdCases)
            ..[sosId] = caseId;
          state = state.copyWith(
            acceptingIds: clearedAccepting,
            createdCases: updatedCases,
          );
          return result;

        case SosAcceptAlreadyTaken():
          // Lost the race (backend returned null). Display "This SOS is already taken"
          final updatedTaken = Set<String>.from(state.alreadyTakenIds)
            ..add(sosId);
          state = state.copyWith(
            acceptingIds: clearedAccepting,
            alreadyTakenIds: updatedTaken,
          );
          return result;

        case SosAcceptFailure(:final message):
          state = state.copyWith(
            acceptingIds: clearedAccepting,
            errorMessage: message,
          );
          return result;
      }
    } catch (e) {
      if (ref.mounted) {
        final clearedAccepting = Set<String>.from(state.acceptingIds)
          ..remove(sosId);
        state = state.copyWith(
          acceptingIds: clearedAccepting,
          errorMessage: e.toString(),
        );
      }
      return SosAcceptFailure(message: e.toString());
    }
  }

  /// Advocate declines / dismisses an SOS alert from their inbox.
  Future<void> decline(String sosId) async {
    final updatedItems = state.items.where((i) => i.id != sosId).toList();
    state = state.copyWith(items: updatedItems);
    try {
      await _repository.declineSos(sosId);
    } catch (_) {
      // Non-critical local dismissal
    }
  }

  /// Refreshes the advocate inbox.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.refresh();
      final items = await _repository.getAdvocateInbox();
      if (ref.mounted) {
        state = state.copyWith(items: items, isLoading: false);
      }
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
    }
  }
}

/// Provider for Advocate SOS Inbox
final sosInboxProvider = NotifierProvider<SosInboxNotifier, SosInboxState>(
  SosInboxNotifier.new,
);
