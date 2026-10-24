import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';
import 'loading_metaphor.dart';
import 'min_tap_target.dart';

/// Semantic sync statuses defined in ui_ux.md §1.1, §4.3 & PRD F8.
enum SyncStatus {
  /// All local changes synced to Supabase backend: '✓ সব সংরক্ষিত (All synced)'
  synced,

  /// Currently syncing outbox queue: '◐ সিংক হচ্ছে… (Syncing)'
  syncing,

  /// Device has no internet connection: '⛌ অফলাইন (Offline)'
  offline,

  /// Offline with queued mutation items: '⛌ অফলাইন — পাঠানোর অপেক্ষায় (queued)'
  queued,
}

/// SyncBadge implementation adhering strictly to ui_ux.md §1.1, §3.3 & §4.3.
///
/// Features:
/// - Offline: stone text/icon, 1 px dashed stone border, calm (never burgundy).
/// - Queued: dashed border with pending item count.
/// - Syncing: animated brass arc (no generic circular spinners!).
/// - Synced: stone checkmark glyph with 'সব সংরক্ষিত'.
/// - Queue warnings: Surfaces warning at >= 50 items and blocking at >= 100 items (PRD F8).
class SyncBadge extends StatelessWidget {
  const SyncBadge({
    super.key,
    required this.status,
    this.pendingCount = 0,
    this.isBanner = false,
    this.customMessage,
    this.onTap,
  });

  /// Factory for standard offline indicator
  const SyncBadge.offline({
    super.key,
    this.pendingCount = 0,
    this.isBanner = false,
    this.customMessage,
    this.onTap,
  }) : status = pendingCount > 0 ? SyncStatus.queued : SyncStatus.offline;

  /// Factory for syncing state
  const SyncBadge.syncing({
    super.key,
    this.pendingCount = 0,
    this.isBanner = false,
    this.customMessage,
    this.onTap,
  }) : status = SyncStatus.syncing;

  /// Factory for all changes saved state
  const SyncBadge.synced({
    super.key,
    this.isBanner = false,
    this.customMessage,
    this.onTap,
  }) : status = SyncStatus.synced,
       pendingCount = 0;

  final SyncStatus status;
  final int pendingCount;
  final bool isBanner;
  final String? customMessage;
  final VoidCallback? onTap;

  /// Whether current queue is in warning threshold (>= 50 ops per PRD F8)
  bool get isQueueWarning => pendingCount >= 50 && pendingCount < 100;

  /// Whether current queue is blocked (>= 100 ops per PRD F8)
  bool get isQueueBlocked => pendingCount >= 100;

  @override
  Widget build(BuildContext context) {
    if (isBanner) {
      return _buildFullBanner(context);
    }
    return _buildCompactBadge(context);
  }

  Widget _buildCompactBadge(BuildContext context) {
    Color textColor;
    Color backgroundColor;
    bool isDashed;

    switch (status) {
      case SyncStatus.offline:
      case SyncStatus.queued:
        textColor = AppColors.stoneText;
        backgroundColor = AppColors.parchment;
        isDashed = true;
        break;
      case SyncStatus.syncing:
        textColor = AppColors.brass;
        backgroundColor = AppColors.brassWash;
        isDashed = false;
        break;
      case SyncStatus.synced:
        textColor = AppColors.oxfordMuted;
        backgroundColor = AppColors.parchmentElevated;
        isDashed = false;
        break;
    }

    final badgeChild = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: isDashed
            ? Border.all(
                color: AppColors.stone,
                width: 1.2,
                strokeAlign: BorderSide.strokeAlignCenter,
              )
            : Border.all(
                color: status == SyncStatus.syncing
                    ? AppColors.brass
                    : AppColors.stone,
                width: 1.0,
              ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildGlyph(textColor),
          const SizedBox(width: 6),
          Text(
            _getLabel(),
            style: AppTypography.caption(color: textColor)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return MinTapTarget(
        minHeight: 48,
        minWidth: 48,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: badgeChild,
        ),
      );
    }

    return Semantics(
      label: 'Sync Status: ${_getAccessibleLabel()}',
      child: badgeChild,
    );
  }

  Widget _buildFullBanner(BuildContext context) {
    if (isQueueBlocked) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.burgundyWash,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.burgundy, width: 1.2),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.burgundy,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'অপেক্ষারতার সীমা পূর্ণ (১০০)। সংযোগ ফিরে আসলে আবার চেষ্টা করুন।',
                style: AppTypography.banglaBody(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.burgundy,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isQueueWarning) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.brassWash,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.brass, width: 1.0),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.brass,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'সংযোগ দুর্বল — পরিবর্তনগুলো পরে সিংক হবে ($pendingCount অপেক্ষায়)।',
                style: AppTypography.banglaBody(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.oxford,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Standard offline/queued banner per ui_ux.md §4.3
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.stone, width: 1.2),
      ),
      child: Row(
        children: [
          _buildGlyph(AppColors.stoneText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              customMessage ?? _getBannerLabel(),
              style: AppTypography.banglaBody(
                fontSize: 16,
                color: AppColors.oxfordSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlyph(Color color) {
    switch (status) {
      case SyncStatus.offline:
        return Icon(Icons.cloud_off_rounded, size: 16, color: color);
      case SyncStatus.queued:
        return Icon(Icons.hourglass_top_rounded, size: 16, color: color);
      case SyncStatus.syncing:
        return const BrassArcLoader(
          size: 14,
          strokeWidth: 2,
          color: AppColors.brass,
        );
      case SyncStatus.synced:
        return Icon(Icons.check_rounded, size: 16, color: color);
    }
  }

  String _getLabel() {
    if (customMessage != null) return customMessage!;
    switch (status) {
      case SyncStatus.offline:
        return '⛌ অফলাইন (Offline)';
      case SyncStatus.queued:
        return '⛌ অফলাইন ($pendingCount অপেক্ষায়)';
      case SyncStatus.syncing:
        return '◐ সিংক হচ্ছে… (Syncing)';
      case SyncStatus.synced:
        return '✓ সব সংরক্ষিত';
    }
  }

  String _getBannerLabel() {
    switch (status) {
      case SyncStatus.offline:
        return 'অফলাইন — কোর্টে সংযোগ নেই (Offline — no connection)';
      case SyncStatus.queued:
        return '⛌ অফলাইন — পাঠানোর অপেক্ষায় (queued)';
      case SyncStatus.syncing:
        return '◐ সার্ভারে সিংক হচ্ছে… (Syncing with server)';
      case SyncStatus.synced:
        return '✓ সব পরিবর্তন সফলভাবে সংরক্ষিত হয়েছে (All changes saved)';
    }
  }

  String _getAccessibleLabel() {
    switch (status) {
      case SyncStatus.offline:
        return 'Offline, no connection';
      case SyncStatus.queued:
        return 'Offline with $pendingCount pending queued changes';
      case SyncStatus.syncing:
        return 'Syncing changes with server';
      case SyncStatus.synced:
        return 'All changes saved and synchronized';
    }
  }
}
