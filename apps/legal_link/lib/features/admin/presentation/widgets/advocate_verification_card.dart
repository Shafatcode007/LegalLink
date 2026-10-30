import 'package:flutter/material.dart';

import '../../../../shared/shared.dart';
import '../../domain/entities/advocate_verification_item.dart';
import 'verification_status_chip.dart';

/// Advocate Verification Card widget for Admin Queue (Sprint 2, Role B2).
class AdvocateVerificationCard extends StatelessWidget {
  const AdvocateVerificationCard({
    super.key,
    required this.item,
    required this.isResolvingUrl,
    required this.onPreview,
    required this.onApprove,
    required this.onReject,
    required this.onOpenProfile,
  });

  final AdvocateVerificationItem item;
  final bool isResolvingUrl;
  final VoidCallback onPreview;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.parchmentElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.stone),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 10),
            _buildCourtDivision(),
            const SizedBox(height: 14),
            _buildDocumentPreviewCard(),
            const SizedBox(height: 18),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.fullName,
                style: AppTypography.displayHeading(fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'বার কাউন্সিল নম্বর: ${item.barCouncilNo}',
                style: AppTypography.uiBody(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brass,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        VerificationStatusChip(status: item.status),
      ],
    );
  }

  Widget _buildCourtDivision() {
    return Row(
      children: [
        const Icon(
          Icons.account_balance_outlined,
          size: 16,
          color: AppColors.stoneText,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            item.courts.isNotEmpty ? item.courts.first : '—',
            style: AppTypography.banglaBody(
              fontSize: 16,
              color: AppColors.oxfordSoft,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.parchmentSunken,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.stone, width: 0.8),
      ),
      child: Row(
        children: [
          _buildDocThumbnail(),
          const SizedBox(width: 10),
          _buildDocDetails(),
          _buildDocPreviewButton(),
        ],
      ),
    );
  }

  Widget _buildDocThumbnail() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.parchmentElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.stone, width: 0.8),
      ),
      child: isResolvingUrl
          ? const Center(child: BrassArcLoader(size: 16, strokeWidth: 2))
          : const Icon(
              Icons.picture_as_pdf_rounded,
              color: AppColors.burgundy,
              size: 20,
            ),
    );
  }

  Widget _buildDocDetails() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'বার সনদপত্র (Sanad)',
                  style: AppTypography.banglaBody(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              _buildSignedBadge(),
            ],
          ),
          Text(
            item.sanadUrl?.split('/').last ?? 'sanad.pdf',
            style: AppTypography.uiBody(
              fontSize: 12,
              color: AppColors.oxfordMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSignedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brassWash,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '🔒 ১৫মি. সাইনড',
        style: AppTypography.caption(
          fontSize: 10,
          color: AppColors.brass,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDocPreviewButton() {
    return MinTapTarget(
      minHeight: 36,
      minWidth: 48,
      child: TextButton.icon(
        onPressed: isResolvingUrl ? null : onPreview,
        icon: isResolvingUrl
            ? const BrassArcLoader(size: 14)
            : const Icon(
                Icons.visibility_outlined,
                size: 16,
                color: AppColors.brass,
              ),
        label: Text(
          isResolvingUrl ? 'লোড হচ্ছে...' : 'প্রিভিউ (Preview)',
          style: AppTypography.uiBody(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.brass,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    if (item.status.isPending) {
      return Row(
        children: [
          Expanded(
            child: AppButton.secondary(
              label: 'প্রত্যাখ্যান (Reject)',
              isFullWidth: true,
              onPressed: onReject,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppButton.primary(
              label: 'অনুমোদন (Approve)',
              isFullWidth: true,
              onPressed: onApprove,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (item.status.isApproved)
          const VerifiedBadge(compact: true)
        else
          Flexible(
            child: Text(
              'আবেদনটি প্রত্যাখ্যাত হয়েছে',
              style: AppTypography.banglaBody(
                fontSize: 16,
                color: AppColors.burgundy,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const SizedBox(width: 8),
        AppButton.ribbon(
          label: 'সম্পূর্ণ প্রোফাইল দেখুন →',
          onPressed: onOpenProfile,
        ),
      ],
    );
  }
}
