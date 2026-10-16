import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';
import 'min_tap_target.dart';

/// Verified Advocate Badge.
/// Strictly uses Forest Green (#2F4A38) with a white seal-check glyph
/// and explicit text 'যাচাইকৃত' / 'Verified' for accessible confirmation.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({
    super.key,
    this.showEnglish = true,
    this.compact = false,
  });

  /// Whether to include the English '(Verified)' next to 'যাচাইকৃত'
  final bool showEnglish;

  /// If true, reduces padding for dense lists
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = showEnglish ? 'যাচাইকৃত (Verified)' : 'যাচাইকৃত';

    return Semantics(
      label: 'যাচাইকৃত আইনজীবী, Bar Council Verified Advocate',
      container: true,
      child: MinTapTarget(
        minHeight: compact ? 32 : 48,
        minWidth: 48,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.verifiedForest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                offset: Offset(0, 1),
                blurRadius: 3,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.verified, color: AppColors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                text,
                style: AppTypography.badgeText(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
