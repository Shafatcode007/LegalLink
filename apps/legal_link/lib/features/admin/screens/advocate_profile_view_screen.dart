import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/shared.dart';
import '../domain/entities/advocate_verification_item.dart';
import '../presentation/notifiers/admin_verification_notifier.dart';
import '../widgets/verification_status_chip.dart';

/// Screen displaying full advocate profile and credentials for administrative review.
class AdvocateProfileViewScreen extends ConsumerWidget {
  const AdvocateProfileViewScreen({super.key, required this.advocateId});

  final String advocateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminVerificationProvider);
    final advocate = ref
        .read(adminVerificationProvider.notifier)
        .getById(advocateId);

    if (advocate == null) {
      return Scaffold(
        backgroundColor: AppColors.parchment,
        appBar: AppBar(
          backgroundColor: AppColors.parchment,
          elevation: 0,
          leading: MinTapTarget(
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.oxford),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          title: Text(
            'প্রোফাইল পাওয়া যায়নি',
            style: AppTypography.displayHeading(fontSize: 20),
          ),
        ),
        body: Center(
          child: Text(
            'আইনজীবীর তথ্য লোড করা যায়নি।',
            style: AppTypography.banglaBody(color: AppColors.oxfordMuted),
          ),
        ),
      );
    }

    if (state.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.parchment,
        body: Center(
          child: GavelBreathingRingLoader(
            message: 'যাচাইকরণ স্থিতি আপডেট করা হচ্ছে...',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: AppBar(
        backgroundColor: AppColors.parchment,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.stone, height: 1.0),
        ),
        leading: MinTapTarget(
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.oxford),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          'আইনজীবী প্রোফাইল (Profile)',
          style: AppTypography.displayHeading(fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.parchmentElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.stone),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    offset: Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Avatar
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.brassWash,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.brass,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 36,
                          color: AppColors.brass,
                        ),
                      ),
                      // Status or Verified Badge
                      if (advocate.status.isApproved)
                        const VerifiedBadge()
                      else
                        VerificationStatusChip(status: advocate.status),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    advocate.fullName,
                    style: AppTypography.displayHeading(fontSize: 22),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.badge_outlined,
                        size: 16,
                        color: AppColors.brass,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'বার কাউন্সিল নম্বর: ${advocate.barCouncilNo}',
                        style: AppTypography.uiBody(
                          fontWeight: FontWeight.w600,
                          color: AppColors.oxfordSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_outlined,
                        size: 16,
                        color: AppColors.stoneText,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                      child: Text(
                        advocate.courts.isNotEmpty
                            ? advocate.courts.first
                            : '—',
                          style: AppTypography.banglaBody(
                            fontSize: 16,
                            color: AppColors.oxfordSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Credentials & Specialization Section
            Text(
              'পেশাগত বিবরণ (Credentials)',
              style: AppTypography.displayHeading(fontSize: 18),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.parchmentElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.stone),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    label: 'অভিজ্ঞতা (Experience)',
                    value: '${advocate.yearsOfExperience} বছর (Years)',
                    icon: Icons.history_edu_rounded,
                  ),
                  const Divider(color: AppColors.stone, height: 24),
                  _buildDetailRow(
                    label: 'দক্ষতা (Specialization)',
                    value: advocate.specializations.isNotEmpty
                        ? advocate.specializations.first
                        : '—',
                    icon: Icons.gavel_rounded,
                  ),
                  const Divider(color: AppColors.stone, height: 24),
                  _buildDetailRow(
                    label: 'মোবাইল (Phone)',
                    value: '—',
                    icon: Icons.phone_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Document Preview Section (Sanad)
            Text(
              'বার সনদপত্র যাচাই (Sanad Document)',
              style: AppTypography.displayHeading(fontSize: 18),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.parchmentSunken,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.stone),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.parchmentElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.stone),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: AppColors.burgundy,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'বাংলাদেশ বার কাউন্সিল সনদপত্র',
                              style: AppTypography.banglaBody(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              advocate.sanadUrl?.split('/').last ?? '—',
                              style: AppTypography.uiBody(
                                fontSize: 13,
                                color: AppColors.oxfordMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Mock Document Preview Frame
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.parchmentElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.stone),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 40,
                          color: AppColors.brass,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'সনদপত্র স্ক্যান প্রিভিউ (${advocate.barCouncilNo})',
                          style: AppTypography.banglaBody(
                            fontSize: 16,
                            color: AppColors.oxfordSoft,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bangladesh Bar Council Certified Copy',
                          style: AppTypography.uiBody(
                            fontSize: 12,
                            color: AppColors.oxfordMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons (If pending or to override)
            if (advocate.status.isPending) ...[
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'প্রত্যাখ্যান (Reject)',
                      isFullWidth: true,
                      onPressed: () async {
                        await ref
                            .read(adminVerificationProvider.notifier)
                            .reject(advocate.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'আইনজীবীর আবেদন প্রত্যাখ্যান করা হয়েছে।',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppButton.primary(
                      label: 'অনুমোদন (Approve)',
                      isFullWidth: true,
                      onPressed: () async {
                        await ref
                            .read(adminVerificationProvider.notifier)
                            .approve(advocate.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'আইনজীবী সফলভাবে অনুমোদিত হয়েছেন!',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: advocate.status.isApproved
                      ? AppColors.brassWash
                      : AppColors.burgundyWash,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      advocate.status.isApproved
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: advocate.status.isApproved
                          ? AppColors.verifiedForest
                          : AppColors.burgundy,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      advocate.status.isApproved
                          ? 'এই আইনজীবী ইতোমধ্যে অনুমোদিত ও যাচাইকৃত।'
                          : 'এই আইনজীবীর আবেদন ইতোমধ্যে প্রত্যাখ্যাত হয়েছে।',
                      style: AppTypography.banglaBody(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.oxford,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.brass),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.uiBody(
                  fontSize: 13,
                  color: AppColors.oxfordMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.banglaBody(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.oxford,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
