import 'package:flutter/material.dart';

import '../../../shared/shared.dart';
import '../models/advocate_verification_item.dart';

/// Status chip adhering to Parchment / Oxford design tokens.
class VerificationStatusChip extends StatelessWidget {
  const VerificationStatusChip({super.key, required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;
    IconData icon;

    switch (status) {
      case VerificationStatus.pending:
        bg = AppColors.brassWash;
        border = AppColors.brass;
        text = AppColors.brassHover;
        icon = Icons.hourglass_top_rounded;
        break;
      case VerificationStatus.approved:
        bg = AppColors.verifiedForest;
        border = AppColors.verifiedForest;
        text = AppColors.white;
        icon = Icons.verified_rounded;
        break;
      case VerificationStatus.rejected:
        bg = AppColors.burgundyWash;
        border = AppColors.burgundy;
        text = AppColors.burgundy;
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: text),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: AppTypography.uiBody(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}
