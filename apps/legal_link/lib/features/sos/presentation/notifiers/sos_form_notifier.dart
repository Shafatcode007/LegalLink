import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/sync_badge.dart';
import '../../domain/entities/sos_request_item.dart';
import '../../domain/repositories/sos_repository.dart';

/// Form state for client SOS submission with offline queueing & SyncBadge (Sprint 2, Role B2).
class SosFormState {
  const SosFormState({
    this.personName = '',
    this.thana = 'ধানমন্ডি মডেল থানা',
    this.district = 'ঢাকা',
    this.court = 'ঢাকা মহানগর দায়রা জজ আদালত',
    this.contactPhone = '',
    this.charges = 'ফৌজদারি কার্যবিধি ৫৪ ধারা',
    this.notes = '',
    this.urgency = SosUrgency.high,
    this.isOffline = false,
    this.syncStatus = SyncStatus.synced,
    this.pendingQueueCount = 0,
    this.isSubmitting = false,
    this.isBroadcastActive = false,
    this.notifiedAdvocatesCount = 0,
    this.submittedRequest,
    this.errorMessage,
  });

  final String personName;
  final String thana;
  final String district;
  final String court;
  final String contactPhone;
  final String charges;
  final String notes;
  final SosUrgency urgency;

  final bool isOffline;
  final SyncStatus syncStatus;
  final int pendingQueueCount;
  final bool isSubmitting;
  final bool isBroadcastActive;
  final int notifiedAdvocatesCount;
  final SosRequestItem? submittedRequest;
  final String? errorMessage;

  bool get isValid =>
      personName.trim().isNotEmpty &&
      thana.trim().isNotEmpty &&
      contactPhone.trim().isNotEmpty;

  SosFormState copyWith({
    String? personName,
    String? thana,
    String? district,
    String? court,
    String? contactPhone,
    String? charges,
    String? notes,
    SosUrgency? urgency,
    bool? isOffline,
    SyncStatus? syncStatus,
    int? pendingQueueCount,
    bool? isSubmitting,
    bool? isBroadcastActive,
    int? notifiedAdvocatesCount,
    SosRequestItem? submittedRequest,
    String? errorMessage,
  }) {
    return SosFormState(
      personName: personName ?? this.personName,
      thana: thana ?? this.thana,
      district: district ?? this.district,
      court: court ?? this.court,
      contactPhone: contactPhone ?? this.contactPhone,
      charges: charges ?? this.charges,
      notes: notes ?? this.notes,
      urgency: urgency ?? this.urgency,
      isOffline: isOffline ?? this.isOffline,
      syncStatus: syncStatus ?? this.syncStatus,
      pendingQueueCount: pendingQueueCount ?? this.pendingQueueCount,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isBroadcastActive: isBroadcastActive ?? this.isBroadcastActive,
      notifiedAdvocatesCount:
          notifiedAdvocatesCount ?? this.notifiedAdvocatesCount,
      submittedRequest: submittedRequest ?? this.submittedRequest,
      errorMessage: errorMessage,
    );
  }
}

/// Riverpod Notifier managing SOS form submissions and offline sync state.
class SosFormNotifier extends Notifier<SosFormState> {
  late SosRepository _repository;

  @override
  SosFormState build() {
    _repository = ref.watch(sosRepositoryProvider);
    return const SosFormState();
  }

  void updatePersonName(String value) =>
      state = state.copyWith(personName: value);
  void updateThana(String value) => state = state.copyWith(thana: value);
  void updateDistrict(String value) => state = state.copyWith(district: value);
  void updateContactPhone(String value) =>
      state = state.copyWith(contactPhone: value);
  void updateCharges(String value) => state = state.copyWith(charges: value);
  void updateNotes(String value) => state = state.copyWith(notes: value);
  void updateUrgency(SosUrgency urgency) =>
      state = state.copyWith(urgency: urgency);

  /// Toggles simulated offline state to test court-basement offline invariant
  void toggleOffline(bool offline) {
    if (offline) {
      state = state.copyWith(
        isOffline: true,
        syncStatus: state.pendingQueueCount > 0
            ? SyncStatus.queued
            : SyncStatus.offline,
      );
    } else {
      // Reconnected -> sync queue if any
      state = state.copyWith(isOffline: false);
      if (state.pendingQueueCount > 0) {
        syncPendingQueue();
      } else {
        state = state.copyWith(syncStatus: SyncStatus.synced);
      }
    }
  }

  /// Broadcasts the SOS request (handles online broadcast or offline queueing)
  Future<void> submitSos() async {
    if (!state.isValid) {
      state = state.copyWith(
        errorMessage: 'অনুগ্রহ করে প্রয়োজনীয় তথ্যগুলো পূরণ করুন।',
      );
      return;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);

    final request = SosRequestItem(
      id: 'sos-${DateTime.now().millisecondsSinceEpoch}',
      clientId: 'client-current',
      personName: state.personName.trim(),
      thana: state.thana.trim(),
      district: state.district.trim(),
      court: state.court.trim(),
      charges: state.charges.trim(),
      contactPhone: state.contactPhone.trim(),
      notes: state.notes.trim().isNotEmpty ? state.notes.trim() : null,
      urgency: state.urgency,
      createdAt: DateTime.now(),
      isQueuedLocally: state.isOffline,
    );

    try {
      if (state.isOffline) {
        // Enqueue locally when offline
        final queued = await _repository.broadcastSos(request, isOffline: true);
        if (ref.mounted) {
          state = state.copyWith(
            isSubmitting: false,
            syncStatus: SyncStatus.queued,
            pendingQueueCount: state.pendingQueueCount + 1,
            submittedRequest: queued,
            isBroadcastActive: false,
          );
        }
      } else {
        // Online send
        state = state.copyWith(syncStatus: SyncStatus.syncing);
        final sent = await _repository.broadcastSos(request, isOffline: false);
        if (ref.mounted) {
          state = state.copyWith(
            isSubmitting: false,
            syncStatus: SyncStatus.synced,
            submittedRequest: sent,
            isBroadcastActive: true,
            notifiedAdvocatesCount: 12,
          );
        }
      }
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isSubmitting: false, errorMessage: e.toString());
      }
    }
  }

  /// Flushes locally queued items when connectivity is restored
  Future<void> syncPendingQueue() async {
    if (state.pendingQueueCount == 0) return;

    state = state.copyWith(syncStatus: SyncStatus.syncing);
    try {
      await _repository.flushOutbox();
      if (ref.mounted) {
        state = state.copyWith(
          syncStatus: SyncStatus.synced,
          pendingQueueCount: 0,
        );
      }
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          syncStatus: SyncStatus.queued,
          errorMessage: 'সিংক সম্পন্ন করা যায়নি। পুনরায় চেষ্টা করা হবে।',
        );
      }
    }
  }
}

/// Provider for SOS Form
final sosFormProvider = NotifierProvider<SosFormNotifier, SosFormState>(
  SosFormNotifier.new,
);
