import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/shared.dart';
import '../../domain/entities/sos_request_item.dart';
import '../notifiers/sos_form_notifier.dart';

/// Screen for reviewing an SOS draft before broadcasting or while offline (Task C).
///
/// Features:
/// 1. Prominent [SyncBadge] clearly communicating Synced, Syncing, or Offline/Queued status.
/// 2. Local Hive queuing status indicator ensuring court-basement durability.
/// 3. Clear review of minimal required fields and optional legal details.
/// 4. Direct confirmation to broadcast live or queue offline.
class SosDraftReviewScreen extends ConsumerWidget {
  const SosDraftReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(sosFormProvider);
    final notifier = ref.read(sosFormProvider.notifier);

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
              'জরুরি SOS খসড়া পর্যালোচনা',
              style: AppTypography.displayHeading(fontSize: 18),
            ),
            Text(
              'Client SOS Draft Review & Offline Queue',
              style: AppTypography.caption(color: AppColors.oxfordMuted),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SyncBadge(
              status: formState.syncStatus,
              pendingCount: formState.pendingQueueCount,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Prominent SyncBadge Full Banner
              SyncBadge(
                status: formState.syncStatus,
                pendingCount: formState.pendingQueueCount,
                isBanner: true,
                onTap: formState.pendingQueueCount > 0
                    ? () => notifier.syncPendingQueue()
                    : null,
              ),
              const SizedBox(height: 14),

              // 2. Local Hive Queuing Status Card
              _buildHiveQueueStatusCard(formState),
              const SizedBox(height: 18),

              // 3. Draft Details Summary Card
              _buildDraftSummaryCard(formState),
              const SizedBox(height: 24),

              // 4. Action Buttons
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'সম্পাদনা করুন (Edit)',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: AppButton.sos(
                      label: formState.isOffline
                          ? 'অফলাইনে কিউ করুন (Queue)'
                          : 'নিশ্চিত করুন ও পাঠান',
                      isLoading: formState.isSubmitting,
                      onPressed: formState.isValid
                          ? () async {
                              await notifier.submitSos();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHiveQueueStatusCard(SosFormState formState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.parchmentElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: formState.isOffline
              ? AppColors.stone
              : AppColors.verifiedForest.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: formState.isOffline
                  ? AppColors.parchmentSunken
                  : const Color(0x182F4A38),
              shape: BoxShape.circle,
            ),
            child: Icon(
              formState.isOffline
                  ? Icons.save_alt_rounded
                  : Icons.cloud_done_rounded,
              size: 22,
              color: formState.isOffline
                  ? AppColors.oxford
                  : AppColors.verifiedForest,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formState.isOffline
                      ? 'স্থানীয় মেমোরি / Hive স্টোরেজে সংরক্ষিত'
                      : 'সার্ভার সংযোগ প্রস্তুত (Ready to Broadcast)',
                  style: AppTypography.banglaBody(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.oxford,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formState.isOffline
                      ? 'কোর্টের বেজমেন্ট বা দুর্বল নেটওয়ার্কেও ডাটা সুরক্ষিত। সংযোগ পেলে স্বয়ংক্রিয়ভাবে ব্রডকাস্ট হবে।'
                      : 'অনলাইন ব্রডকাস্ট সক্রিয় — সরাসরি নিকটবর্তী আইনজীবীদের ইনবক্সে পৌঁছে যাবে।',
                  style: AppTypography.caption(color: AppColors.oxfordMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftSummaryCard(SosFormState formState) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.parchmentElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stone),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'খসড়া তথ্যসমূহ',
                style: AppTypography.displayHeading(fontSize: 18),
              ),
              _buildUrgencyBadge(formState.urgency),
            ],
          ),
          const Divider(color: AppColors.stone, height: 24),
          _buildDetailItem(
            label: 'আটককৃত ব্যক্তির নাম',
            value: formState.personName.isEmpty ? '—' : formState.personName,
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),
          _buildDetailItem(
            label: 'থানা (Thana)',
            value: formState.thana.isEmpty ? '—' : formState.thana,
            icon: Icons.local_police_outlined,
          ),
          const SizedBox(height: 12),
          _buildDetailItem(
            label: 'জেলা / আদালত',
            value: formState.court.isEmpty ? '—' : formState.court,
            icon: Icons.account_balance_outlined,
          ),
          const SizedBox(height: 12),
          _buildDetailItem(
            label: 'জরুরি যোগাযোগের ফোন নম্বর',
            value: formState.contactPhone.isEmpty
                ? '—'
                : formState.contactPhone,
            icon: Icons.phone_outlined,
          ),
          if (formState.charges.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailItem(
              label: 'অভিযোগ / ধারা',
              value: formState.charges,
              icon: Icons.gavel_outlined,
            ),
          ],
          if (formState.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailItem(
              label: 'বিশেষ নির্দেশনা / নোট',
              value: formState.notes,
              icon: Icons.notes_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.brass),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption(color: AppColors.oxfordMuted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.banglaBody(
                  fontSize: 15,
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

  Widget _buildUrgencyBadge(SosUrgency urgency) {
    final Color color = urgency == SosUrgency.critical
        ? AppColors.burgundy
        : AppColors.brass;
    final String label = urgency == SosUrgency.critical
        ? 'অতি জরুরি (Critical)'
        : 'উচ্চ গুরুত্ব (High)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        label,
        style: AppTypography.caption(color: color)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
