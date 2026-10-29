import 'package:flutter/material.dart';

import '../../../../shared/shared.dart';
import '../../domain/entities/sos_request_item.dart';

/// Advocate SOS Card (Task B) implementing:
/// 1. Urgent burgundy design token aesthetics (ui_ux.md §1.1, §3.3)
/// 2. Single Accept Flow UI: instant lock on tap, displays prominent "Case Created" on backend success
/// 3. Losing Advocate UI: renders in-place disabled state "This SOS is already taken" with subtle
///    Oxford Muted text and dismiss action when backend returns null
class SosCard extends StatelessWidget {
  const SosCard({
    super.key,
    required this.item,
    required this.isAccepting,
    required this.isCaseCreated,
    required this.isAlreadyTaken,
    this.createdCaseId,
    required this.onAccept,
    required this.onDecline,
    this.onViewCase,
    this.onCallClient,
  });

  final SosRequestItem item;
  final bool isAccepting;
  final bool isCaseCreated;
  final bool isAlreadyTaken;
  final String? createdCaseId;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onViewCase;
  final VoidCallback? onCallClient;

  @override
  Widget build(BuildContext context) {
    if (isCaseCreated) {
      return _buildCaseCreatedState(context);
    }

    if (isAlreadyTaken) {
      return _buildAlreadyTakenState(context);
    }

    return _buildActiveAlertState(context);
  }

  /// 1. Active Open Alert State
  Widget _buildActiveAlertState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.burgundyWash,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.urgency == SosUrgency.critical
              ? AppColors.burgundy
              : AppColors.stone,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x147A2230),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Siren Badge & Distance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.burgundy,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.crisis_alert_rounded,
                        color: AppColors.parchment,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'জরুরি SOS',
                              style: AppTypography.displayHeading(
                                fontSize: 16,
                                color: AppColors.burgundy,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.burgundy,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '● চলমান (Live)',
                                style: AppTypography.caption(
                                  fontSize: 10,
                                  color: AppColors.parchment,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          item.thana,
                          style: AppTypography.banglaBody(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.oxford,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Distance badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.parchmentElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.stone, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.near_me_outlined,
                        size: 14,
                        color: AppColors.stoneText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.distanceKm.toStringAsFixed(1)} কিমি দূরে',
                        style: AppTypography.caption(
                          fontSize: 12,
                          color: AppColors.stoneText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Captured Minimal Details Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.parchmentElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.stone, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'আটককৃত ব্যক্তি: ${item.personName}',
                    style: AppTypography.banglaBody(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.oxford,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'থানা ও জেলা: ${item.thana}, ${item.district}',
                    style: AppTypography.caption(
                      fontSize: 13,
                      color: AppColors.oxfordSoft,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'অভিযোগ / ধারা: ${item.charges}',
                    style: AppTypography.banglaBody(
                      fontSize: 16,
                      color: AppColors.oxfordSoft,
                    ),
                  ),
                  if (item.notes != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'নোট: ${item.notes}',
                      style: AppTypography.caption(
                        fontSize: 13,
                        color: AppColors.oxfordMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Action Buttons: Accept & Decline (Instantly lock when isAccepting)
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: 'পারবেন না (Decline)',
                    isFullWidth: true,
                    onPressed: isAccepting ? null : onDecline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton.primary(
                    label: isAccepting ? 'লক হচ্ছে...' : 'গ্রহণ করুন (Accept)',
                    isFullWidth: true,
                    isLoading: isAccepting,
                    onPressed: isAccepting ? null : onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 2. Single Accept Flow UI State: "Case Created" (Task B)
  Widget _buildCaseCreatedState(BuildContext context) {
    final caseId =
        createdCaseId ?? 'CASE-2026-${item.id.substring(0, 6).toUpperCase()}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.parchmentElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.verifiedForest, width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x122F4A38),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Success Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.verifiedForest,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.parchment,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Case Created',
                            style: AppTypography.displayHeading(
                              fontSize: 18,
                              color: AppColors.verifiedForest,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const VerifiedBadge(compact: true),
                        ],
                      ),
                      Text(
                        'মামলা তৈরি হয়েছে — আপনি দায়িত্ব পেয়েছেন',
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
            ),
            const SizedBox(height: 16),

            // Case Details Strip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.parchmentSunken,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.stone, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'মামলা নম্বর: $caseId',
                          style: AppTypography.uiBody(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brass,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'আদালত: ${item.court}',
                        style: AppTypography.caption(
                          color: AppColors.oxfordMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ক্লায়েন্ট: ${item.personName} (${item.contactPhone})',
                    style: AppTypography.banglaBody(
                      fontSize: 16,
                      color: AppColors.oxford,
                    ),
                  ),
                  Text(
                    'থানা: ${item.thana}',
                    style: AppTypography.caption(
                      fontSize: 13,
                      color: AppColors.oxfordSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Action CTAs for Won Case
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: 'ক্লায়েন্টকে কল করুন',
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                    isFullWidth: true,
                    onPressed: onCallClient ?? () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton.primary(
                    label: 'মামলার বিবরণ দেখুন →',
                    isFullWidth: true,
                    onPressed: onViewCase ?? () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 3. Losing Advocate UI State: "This SOS is already taken" (Task B)
  Widget _buildAlreadyTakenState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stone, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Locked / Taken Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.parchmentSunken,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.stoneText,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This SOS is already taken',
                        style: AppTypography.displayHeading(
                          fontSize: 16,
                          color: AppColors.stoneText,
                        ),
                      ),
                      Text(
                        'এই SOS ইতিমধ্যে অন্য একজন আইনজীবী গ্রহণ করেছেন',
                        style: AppTypography.banglaBody(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.oxfordMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.parchmentSunken,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'গৃহীত (Taken)',
                    style: AppTypography.caption(
                      fontSize: 11,
                      color: AppColors.stoneText,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Calm Explanatory Well in Oxford Muted
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.parchmentElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.stone, width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.stoneText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'দৌড়ে আপনি পেছনে পড়েছেন — অন্য একজন যাচাইকৃত আইনজীবী দ্রুত সাড়া দিয়েছেন।',
                      style: AppTypography.caption(
                        fontSize: 13,
                        color: AppColors.oxfordMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Dismiss Button Only (No Action Enabled)
            Align(
              alignment: Alignment.centerRight,
              child: AppButton.secondary(
                label: 'ইনবক্স থেকে সরান (Dismiss)',
                onPressed: onDecline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
