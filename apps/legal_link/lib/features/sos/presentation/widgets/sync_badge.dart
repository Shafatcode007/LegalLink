import 'package:flutter/material.dart';

import '../../../../shared/shared.dart';

/// Semantic sync statuses defined in ui_ux.md §1.1, §4.3 & PRD F8.
enum SyncStatus {
  /// All local changes synced to Supabase backend: '✓ সব সংরক্ষিত (All synced)'
  synced,

  /// Currently syncing outbox queue: '◐ সিংক হচ্ছে… (Syncing)'
  syncing,

  /// Device has no internet connection: '⛌ অফলাইন (Offline)'
  offline,

  /// Offline with queued mutation items: '⛌ অফলাইন সংরক্ষিত (Queued locally)'
  queued,
}

/// SyncBadge implementation (Task C) adhering strictly to design system:
///
/// Visual states:
/// 1. Synced: Forest green dot/badge (AppColors.verifiedForest 0xFF2F4A38)
/// 2. Syncing: Pulsing brass sync glyph (AppColors.brass 0xFF7F5B12)
/// 3. Offline/Queued: Stone/Oxford soft badge showing "Queued locally" or "অফলাইন সংরক্ষিত"
///
/// Features:
/// - Queue thresholds: surfaces warning banner at >=50 items, blocking at >=100 items
/// - MinTapTarget (48x48 dp) wrapper for interactive touch points
/// - Supports both compact badge mode and full banner mode
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
    final Color textColor;
    final Color backgroundColor;
    final Color borderColor;
    final Widget glyph;

    switch (status) {
      case SyncStatus.synced:
        textColor = AppColors.verifiedForest;
        backgroundColor = const Color(0x182F4A38); // Forest green wash
        borderColor = AppColors.verifiedForest.withValues(alpha: 0.4);
        glyph = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.verifiedForest,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.check_rounded,
              size: 14,
              color: AppColors.verifiedForest,
            ),
          ],
        );
        break;

      case SyncStatus.syncing:
        textColor = AppColors.brass;
        backgroundColor = AppColors.brassWash;
        borderColor = AppColors.brass;
        glyph = const BrassArcLoader(
          size: 14,
          strokeWidth: 2,
          color: AppColors.brass,
        );
        break;

      case SyncStatus.offline:
      case SyncStatus.queued:
        textColor = AppColors.oxford;
        backgroundColor = AppColors.parchmentElevated;
        borderColor = AppColors.stone;
        glyph = Icon(
          status == SyncStatus.queued
              ? Icons.cloud_queue_rounded
              : Icons.cloud_off_rounded,
          size: 15,
          color: AppColors.oxfordMuted,
        );
        break;
    }

    final badgeChild = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          glyph,
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

    // Standard banner state
    final Color bannerBg;
    final Color bannerBorder;
    final Widget bannerGlyph;

    switch (status) {
      case SyncStatus.synced:
        bannerBg = const Color(0x142F4A38);
        bannerBorder = AppColors.verifiedForest.withValues(alpha: 0.4);
        bannerGlyph = Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.verifiedForest,
            shape: BoxShape.circle,
          ),
        );
        break;

      case SyncStatus.syncing:
        bannerBg = AppColors.brassWash;
        bannerBorder = AppColors.brass;
        bannerGlyph = const BrassArcLoader(
          size: 16,
          strokeWidth: 2,
          color: AppColors.brass,
        );
        break;

      case SyncStatus.offline:
      case SyncStatus.queued:
        bannerBg = AppColors.parchment;
        bannerBorder = AppColors.stone;
        bannerGlyph = Icon(
          status == SyncStatus.queued
              ? Icons.cloud_queue_rounded
              : Icons.cloud_off_rounded,
          size: 18,
          color: AppColors.oxfordMuted,
        );
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bannerBorder, width: 1.2),
      ),
      child: Row(
        children: [
          bannerGlyph,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              customMessage ?? _getBannerLabel(),
              style:
                  AppTypography.banglaBody(
                    fontSize: 16,
                    color: status == SyncStatus.synced
                        ? AppColors.verifiedForest
                        : AppColors.oxfordSoft,
                  ).copyWith(
                    fontWeight: status == SyncStatus.synced
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
            ),
          ),
          if (status == SyncStatus.queued && onTap != null) ...[
            const SizedBox(width: 8),
            MinTapTarget(
              minHeight: 36,
              minWidth: 48,
              child: TextButton(
                onPressed: onTap,
                child: Text(
                  'সিংক করুন',
                  style: AppTypography.caption(color: AppColors.brass)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getLabel() {
    if (customMessage != null) return customMessage!;
    switch (status) {
      case SyncStatus.synced:
        return '✓ সব সংরক্ষিত';
      case SyncStatus.syncing:
        return '◐ সিংক হচ্ছে… (Syncing)';
      case SyncStatus.offline:
        return 'অফলাইন সংরক্ষিত (Queued locally)';
      case SyncStatus.queued:
        return 'অফলাইন সংরক্ষিত ($pendingCount অপেক্ষায়)';
    }
  }

  String _getBannerLabel() {
    switch (status) {
      case SyncStatus.synced:
        return '✓ সব পরিবর্তন সফলভাবে সংরক্ষিত হয়েছে (All changes saved)';
      case SyncStatus.syncing:
        return '◐ সার্ভারে সিংক হচ্ছে… (Syncing with server)';
      case SyncStatus.offline:
        return 'অফলাইন — কোর্টে সংযোগ নেই (Offline — no connection)';
      case SyncStatus.queued:
        return '⛌ অফলাইন — পাঠানোর অপেক্ষায় (queued)';
    }
  }

  String _getAccessibleLabel() {
    switch (status) {
      case SyncStatus.synced:
        return 'All changes saved and synchronized';
      case SyncStatus.syncing:
        return 'Syncing changes with server';
      case SyncStatus.offline:
        return 'Offline, changes queued locally in storage';
      case SyncStatus.queued:
        return 'Offline with $pendingCount pending queued items';
    }
  }
}
