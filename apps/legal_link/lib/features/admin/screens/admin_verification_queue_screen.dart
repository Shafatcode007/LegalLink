import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/shared.dart';
import '../domain/entities/advocate_verification_item.dart';
import '../presentation/notifiers/admin_verification_notifier.dart';
import '../widgets/verification_status_chip.dart';
import 'advocate_profile_view_screen.dart';

/// Screen displaying the administrative queue of advocates awaiting verification.
class AdminVerificationQueueScreen extends ConsumerWidget {
  const AdminVerificationQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminVerificationProvider);
    final notifier = ref.read(adminVerificationProvider.notifier);

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'আইনজীবী যাচাইকরণ কিউ',
              style: AppTypography.displayHeading(fontSize: 20),
            ),
            Text(
              'Admin Verification Queue (Role B2)',
              style: AppTypography.uiBody(
                fontSize: 12,
                color: AppColors.oxfordMuted,
              ),
            ),
          ],
        ),
        actions: [
          MinTapTarget(
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.brass),
              tooltip: 'রিফ্রেশ করুন',
              onPressed: () => notifier.refresh(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isLoading
          ? const Center(
              child: GavelBreathingRingLoader(
                message: 'যাচাইকরণ তালিকা লোড হচ্ছে...',
              ),
            )
          : Column(
              children: [
                // Filter Bar
                _buildFilterBar(context, ref, state),
                const Divider(color: AppColors.stone, height: 1),

                // Main Queue Content
                Expanded(
                  child: state.filteredItems.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                          itemCount: state.filteredItems.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final item = state.filteredItems[index];
                            return _buildAdvocateCard(context, ref, item);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    WidgetRef ref,
    AdminVerificationState state,
  ) {
    final notifier = ref.read(adminVerificationProvider.notifier);

    return Container(
      color: AppColors.parchmentElevated,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: 'সব (${state.items.length})',
              isSelected: state.filter == null,
              onTap: () => notifier.setFilter(null),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'অপেক্ষমান (${state.pendingCount})',
              isSelected: state.filter == VerificationStatus.pending,
              onTap: () => notifier.setFilter(VerificationStatus.pending),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'অনুমোদিত (${state.approvedCount})',
              isSelected: state.filter == VerificationStatus.approved,
              onTap: () => notifier.setFilter(VerificationStatus.approved),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'প্রত্যাখ্যাত (${state.rejectedCount})',
              isSelected: state.filter == VerificationStatus.rejected,
              onTap: () => notifier.setFilter(VerificationStatus.rejected),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return MinTapTarget(
      minHeight: 40,
      minWidth: 48,
      child: Material(
        color: isSelected ? AppColors.brass : AppColors.parchment,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.brass : AppColors.stone,
                width: 1.2,
              ),
            ),
            child: Text(
              label,
              style: AppTypography.uiBody(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.parchment : AppColors.oxford,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvocateCard(
    BuildContext context,
    WidgetRef ref,
    AdvocateVerificationItem item,
  ) {
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
            // Top Row: Name & Status Chip
            Row(
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
            ),
            const SizedBox(height: 10),

            // Court Division
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
                    item.courts.isNotEmpty ? item.courts.first : '—',
                    style: AppTypography.banglaBody(
                      fontSize: 16,
                      color: AppColors.oxfordSoft,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Document Preview Placeholder
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.parchmentSunken,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.stone, width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: AppColors.brass,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'বার কাউন্সিল সনদপত্র (Sanad Document)',
                          style: AppTypography.banglaBody(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          item.sanadUrl?.split('/').last ?? '—',
                          style: AppTypography.uiBody(
                            fontSize: 12,
                            color: AppColors.oxfordMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  MinTapTarget(
                    minHeight: 36,
                    minWidth: 48,
                    child: TextButton.icon(
                      onPressed: () => _openProfile(context, item.id),
                      icon: const Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: AppColors.brass,
                      ),
                      label: Text(
                        'দেখুন (View)',
                        style: AppTypography.uiBody(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brass,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Bottom Actions: Approve & Reject (or View Profile link)
            if (item.status.isPending) ...[
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'প্রত্যাখ্যান (Reject)',
                      isFullWidth: true,
                      onPressed: () => ref
                          .read(adminVerificationProvider.notifier)
                          .reject(item.id),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton.primary(
                      label: 'অনুমোদন (Approve)',
                      isFullWidth: true,
                      onPressed: () => ref
                          .read(adminVerificationProvider.notifier)
                          .approve(item.id),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (item.status.isApproved)
                    const VerifiedBadge(compact: true)
                  else
                    Text(
                      'আবেদনটি প্রত্যাখ্যাত হয়েছে',
                      style: AppTypography.banglaBody(
                        fontSize: 16,
                        color: AppColors.burgundy,
                      ),
                    ),
                  AppButton.ribbon(
                    label: 'সম্পূর্ণ প্রোফাইল দেখুন →',
                    onPressed: () => _openProfile(context, item.id),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.brassWash,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                color: AppColors.brass,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'কোন অপেক্ষমান আবেদন নেই',
              style: AppTypography.displayHeading(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'এই মুহূর্তে যাচাইকরণের জন্য কোনো আইনজীবীর আবেদন জমা নেই।',
              style: AppTypography.banglaBody(
                fontSize: 16,
                color: AppColors.oxfordMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _openProfile(BuildContext context, String advocateId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdvocateProfileViewScreen(advocateId: advocateId),
      ),
    );
  }
}
