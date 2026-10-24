import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/shared.dart';
import '../../domain/entities/sos_accept_result.dart';
import '../notifiers/sos_inbox_notifier.dart';
import '../widgets/sos_alert_card.dart';

/// Screen displaying the Advocate SOS Inbox with real-time alert cards.
class AdvocateSosInboxScreen extends ConsumerStatefulWidget {
  const AdvocateSosInboxScreen({super.key});

  @override
  ConsumerState<AdvocateSosInboxScreen> createState() =>
      _AdvocateSosInboxScreenState();
}

class _AdvocateSosInboxScreenState
    extends ConsumerState<AdvocateSosInboxScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(sosInboxProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sosInboxProvider);
    final notifier = ref.read(sosInboxProvider.notifier);

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
            Row(
              children: [
                Text(
                  'জরুরি SOS ইনবক্স',
                  style: AppTypography.displayHeading(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.burgundy,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            Text(
              'Advocate Emergency Inbox (${state.liveAlertsCount} alerts)',
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
                message: 'জরুরি SOS অ্যালার্ট লোড হচ্ছে...',
              ),
            )
          : state.items.isEmpty
          ? _buildEmptyState(context)
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              itemCount: state.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = state.items[index];
                return SosAlertCard(
                  item: item,
                  isAccepting: state.isAccepting(item.id),
                  isCaseCreated: state.isCaseCreated(item.id),
                  isAlreadyTaken: state.isAlreadyTaken(item.id),
                  createdCaseId: state.getCreatedCaseId(item.id),
                  onAccept: () async {
                    final result = await notifier.accept(item.id);
                    if (!context.mounted) return;
                    if (result is! SosAcceptAlreadyTaken) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.verifiedForest,
                          content: Text(
                            '✓ SOS সফলভাবে গৃহীত হয়েছে! মামলা তৈরি হয়েছে।',
                          ),
                        ),
                      );
                    }
                  },
                  onDecline: () => notifier.decline(item.id),
                  onViewCase: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.oxford,
                        content: Text(
                          'মামলা ${state.getCreatedCaseId(item.id)} ওপেন করা হচ্ছে...',
                        ),
                      ),
                    );
                  },
                  onCallClient: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.oxford,
                        content: Text('কল করা হচ্ছে: ${item.contactPhone}'),
                      ),
                    );
                  },
                );
              },
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
                color: AppColors.parchmentElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.gavel_rounded,
                color: AppColors.stoneText,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'কোনো সক্রিয় জরুরি SOS নেই',
              style: AppTypography.displayHeading(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'এই মুহূর্তে আপনার এলাকায় কোনো নতুন জরুরি SOS অ্যালার্ট নেই। নতুন অ্যালার্ট আসলে তাৎক্ষণিক জানানো হবে।',
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
}
