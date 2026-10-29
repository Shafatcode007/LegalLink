import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/shared.dart';
import '../providers/admin_verification_provider.dart';
import '../widgets/document_preview_dialog.dart';
import '../widgets/verification_status_chip.dart';
import 'advocate_profile_view_screen.dart';

/// Screen displaying the administrative queue of advocates awaiting verification.
///
/// Features (Sprint 2, Role B2):
/// 1. Real Supabase backend wired with signed URLs (ADR-011).
/// 2. Document preview with zoom / full-screen inspection dialog.
/// 3. Branded breathing gavel shimmer skeleton state while signed URL or queue is resolving.
/// 4. Direct Approve & Reject actions with instant optimistic state updates and feedback.
class AdminVerificationQueueScreen extends ConsumerStatefulWidget {
  const AdminVerificationQueueScreen({super.key});

  @override
  ConsumerState<AdminVerificationQueueScreen> createState() =>
      _AdminVerificationQueueScreenState();
}

class _AdminVerificationQueueScreenState
    extends ConsumerState<AdminVerificationQueueScreen> {
  final Set<String> _resolvingSignedUrlIds = {};

  Future<void> _handleViewDocumentPreview(
    BuildContext context,
    AdvocateVerificationItem item,
  ) async {
    setState(() => _resolvingSignedUrlIds.add(item.id));
    try {
      // Ensure signed URL is fresh (15-min window per ADR-011)
      if (!item.isSignedUrlValid) {
        await ref
            .read(adminVerificationProvider.notifier)
            .getSignedUrlFor(item.id);
      }
    } finally {
      if (mounted) {
        setState(() => _resolvingSignedUrlIds.remove(item.id));
      }
    }

    if (!context.mounted) return;

    final freshItem =
        ref.read(adminVerificationProvider.notifier).getById(item.id) ?? item;

    DocumentPreviewDialog.show(
      context,
      advocate: freshItem,
      onApprove: () => _handleApprove(context, item.id),
      onReject: () => _handleReject(context, item.id),
      onRefreshSignedUrl: () =>
          ref.read(adminVerificationProvider.notifier).getSignedUrlFor(item.id),
    );
  }

  Future<void> _handleApprove(BuildContext context, String advocateId) async {
    final notifier = ref.read(adminVerificationProvider.notifier);
    await notifier.approve(advocateId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.verifiedForest,
        content: Text('✓ আইনজীবী সফলভাবে অনুমোদিত হয়েছে (Advocate Approved)'),
      ),
    );
  }

  Future<void> _handleReject(BuildContext context, String advocateId) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.parchment,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.stone),
        ),
        title: Text(
          'প্রত্যাখ্যানের কারণ লিখুন',
          style: AppTypography.displayHeading(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'আইনজীবীর সনদ বা নথিপত্র বাতিলের সুনির্দিষ্ট কারণ উল্লেখ করুন:',
              style: AppTypography.caption(color: AppColors.oxfordMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: AppTypography.uiBody(color: AppColors.oxford),
              decoration: InputDecoration(
                hintText: 'যেমন: বার সনদপত্র অস্পষ্ট বা মেয়াদোত্তীর্ণ...',
                hintStyle: AppTypography.caption(color: AppColors.stoneText),
                filled: true,
                fillColor: AppColors.parchmentElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.stone),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'বাতিল',
              style: AppTypography.uiBody(color: AppColors.oxfordMuted),
            ),
          ),
          AppButton.secondary(
            label: 'প্রত্যাখ্যান নিশ্চিত করুন',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final reason = reasonController.text.trim();
      final notifier = ref.read(adminVerificationProvider.notifier);
      await notifier.reject(
        advocateId,
        reason: reason.isNotEmpty ? reason : null,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.oxford,
          content: Text('আবেদনটি প্রত্যাখ্যাত হয়েছে (Advocate Rejected)'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          ? _buildBreathingGavelShimmerQueue()
          : Column(
              children: [
                if (state.errorMessage != null &&
                    state.filteredItems.isNotEmpty)
                  _buildErrorBanner(context, ref, state.errorMessage!),
                // Filter Bar
                _buildFilterBar(context, ref, state),
                const Divider(color: AppColors.stone, height: 1),

                // Main Queue Content
                Expanded(
                  child: state.filteredItems.isEmpty
                      ? (state.errorMessage != null
                            ? _buildErrorView(context, ref, state.errorMessage!)
                            : _buildEmptyState(context))
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

  /// Branded breathing gavel shimmer skeleton loading state per ui_ux.md §4.2
  Widget _buildBreathingGavelShimmerQueue() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // Centered breathing gavel glyph
          const Center(
            child: GavelBreathingRingLoader(
              message: 'যাচাইকরণ তালিকা লোড হচ্ছে...',
              size: 64,
            ),
          ),
          const SizedBox(height: 28),

          // Shimmer skeleton cards
          for (int i = 0; i < 3; i++) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.parchmentElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.stone.withValues(alpha: 0.6),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      LegalSkeletonLoader(width: 180, height: 20),
                      LegalSkeletonLoader(
                        width: 90,
                        height: 24,
                        borderRadius: 12,
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  LegalSkeletonLoader(width: 140, height: 14),
                  SizedBox(height: 14),
                  LegalSkeletonLoader(
                    width: double.infinity,
                    height: 52,
                    borderRadius: 8,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: LegalSkeletonLoader(
                          height: 44,
                          borderRadius: 22,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: LegalSkeletonLoader(
                          height: 44,
                          borderRadius: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
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
    final isResolvingUrl = _resolvingSignedUrlIds.contains(item.id);

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

            // Document Preview Card with Signed URL (ADR-011)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.parchmentSunken,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.stone, width: 0.8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.parchmentElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.stone, width: 0.8),
                    ),
                    child: isResolvingUrl
                        ? const Center(
                            child: BrassArcLoader(size: 16, strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: AppColors.burgundy,
                            size: 20,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
                            ),
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
                  ),
                  MinTapTarget(
                    minHeight: 36,
                    minWidth: 48,
                    child: TextButton.icon(
                      onPressed: isResolvingUrl
                          ? null
                          : () => _handleViewDocumentPreview(context, item),
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
                      onPressed: () => _handleReject(context, item.id),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton.primary(
                      label: 'অনুমোদন (Approve)',
                      isFullWidth: true,
                      onPressed: () => _handleApprove(context, item.id),
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

  Widget _buildErrorBanner(
    BuildContext context,
    WidgetRef ref,
    String errorMessage,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.burgundy.withValues(alpha: 0.08),
        border: const Border(
          bottom: BorderSide(color: AppColors.burgundy, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.burgundy,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'সার্ভার ত্রুটি / RLS সমস্যা',
                  style: AppTypography.banglaBody(
                    fontSize: 16,
                    color: AppColors.burgundy,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  errorMessage,
                  style: AppTypography.uiBody(
                    fontSize: 12,
                    color: AppColors.oxfordMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MinTapTarget(
            child: TextButton.icon(
              onPressed: () =>
                  ref.read(adminVerificationProvider.notifier).refresh(),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 16,
                color: AppColors.brass,
              ),
              label: Text(
                'পুনরায় চেষ্টা',
                style: AppTypography.banglaBody(
                  fontSize: 16,
                  color: AppColors.brass,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(
    BuildContext context,
    WidgetRef ref,
    String errorMessage,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.burgundy.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.burgundy,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'যাচাইকরণ তালিকা লোড করা যায়নি',
              style: AppTypography.displayHeading(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: AppTypography.banglaBody(
                fontSize: 16,
                color: AppColors.oxfordMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppButton.primary(
              label: 'পুনরায় চেষ্টা করুন (Retry)',
              onPressed: () =>
                  ref.read(adminVerificationProvider.notifier).refresh(),
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
