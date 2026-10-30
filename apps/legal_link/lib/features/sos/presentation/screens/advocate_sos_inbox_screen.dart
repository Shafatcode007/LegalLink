import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/shared.dart';
import '../../domain/entities/sos_request_item.dart';
import '../notifiers/sos_inbox_notifier.dart';
import '../widgets/sos_card.dart';

/// Screen displaying the Advocate SOS Inbox with real-time alert cards.
///
/// Implements (Sprint 2, Role B2):
/// 1. Single Accept Flow: instant button lock, optimistic locked state.
/// 2. Winning advocate: prominent "Case Created" confirmation banner on card AND modal dialog with route to case details.
/// 3. Losing advocate: in-place disabled state "This SOS is already taken" with subtle Oxford Muted text & dismiss action.
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

  Future<void> _handleAccept(BuildContext context, SosRequestItem item) async {
    final notifier = ref.read(sosInboxProvider.notifier);
    final result = await notifier.accept(item.id);

    if (!context.mounted) return;

    if (result is SosAcceptSuccess) {
      // Transition to prominent "Case Created" confirmation dialog
      _showCaseCreatedConfirmationDialog(context, item, result.caseId);
    }
  }

  void _showCaseCreatedConfirmationDialog(
    BuildContext context,
    SosRequestItem item,
    String caseId,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.oxford.withValues(alpha: 0.65),
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.parchment,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.verifiedForest, width: 1.5),
        ),
        title: _buildCaseCreatedDialogTitle(),
        content: _buildCaseCreatedDialogContent(item, caseId),
        actions: _buildCaseCreatedDialogActions(ctx, context, caseId),
      ),
    );
  }

  Widget _buildCaseCreatedDialogTitle() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: AppColors.verifiedForest,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: AppColors.parchment,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Case Created',
                style: AppTypography.displayHeading(
                  fontSize: 18,
                  color: AppColors.verifiedForest,
                ),
              ),
              Text(
                'মামলা সফলভাবে তৈরি হয়েছে',
                style: AppTypography.caption(
                  fontSize: 12,
                  color: AppColors.oxfordMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaseCreatedDialogContent(SosRequestItem item, String caseId) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCaseSummaryCard(item, caseId),
        const SizedBox(height: 12),
        Text(
          'আপনি সফলভাবে এই জরুরি মামলাটি গ্রহণ করেছেন। অবিলম্বে ক্লায়েন্টের সাথে যোগাযোগ করুন।',
          style: AppTypography.caption(color: AppColors.oxfordSoft),
        ),
      ],
    );
  }

  Widget _buildCaseSummaryCard(SosRequestItem item, String caseId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.parchmentElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.stone),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'মামলা নম্বর: $caseId',
            style: AppTypography.uiBody(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.brass,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ক্লায়েন্ট: ${item.personName}',
            style: AppTypography.banglaBody(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.oxford,
            ),
          ),
          Text(
            'ফোন: ${item.contactPhone}',
            style: AppTypography.uiBody(
              fontSize: 13,
              color: AppColors.oxfordSoft,
            ),
          ),
          Text(
            'থানা ও আদালত: ${item.thana}, ${item.court}',
            style: AppTypography.caption(color: AppColors.oxfordMuted),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCaseCreatedDialogActions(
    BuildContext ctx,
    BuildContext context,
    String caseId,
  ) {
    return [
      TextButton(
        onPressed: () => Navigator.of(ctx).pop(),
        child: Text(
          'বন্ধ করুন',
          style: AppTypography.uiBody(color: AppColors.oxfordMuted),
        ),
      ),
      AppButton.primary(
        label: 'মামলার বিবরণ দেখুন →',
        onPressed: () {
          Navigator.of(ctx).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.oxford,
              content: Text('মামলা $caseId বিবরণ পেজে নেভিগেট করা হচ্ছে...'),
            ),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sosInboxProvider);
    final notifier = ref.read(sosInboxProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.parchment,
      appBar: _buildInboxAppBar(state, notifier),
      body: _buildInboxBody(context, state, notifier),
    );
  }

  PreferredSizeWidget _buildInboxAppBar(
    SosInboxState state,
    SosInboxNotifier notifier,
  ) {
    return AppBar(
      backgroundColor: AppColors.parchment,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: AppColors.stone, height: 1.0),
      ),
      title: _buildAppBarTitle(state),
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
    );
  }

  Widget _buildAppBarTitle(SosInboxState state) {
    return Column(
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
    );
  }

  Widget _buildInboxBody(
    BuildContext context,
    SosInboxState state,
    SosInboxNotifier notifier,
  ) {
    if (state.isLoading) {
      return const Center(
        child: GavelBreathingRingLoader(
          message: 'জরুরি SOS অ্যালার্ট লোড হচ্ছে...',
        ),
      );
    }
    if (state.items.isEmpty) {
      return _buildEmptyState(context);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemCount: state.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = state.items[index];
        return _buildAlertCard(context, state, notifier, item);
      },
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    SosInboxState state,
    SosInboxNotifier notifier,
    SosRequestItem item,
  ) {
    return SosCard(
      item: item,
      isAccepting: state.isAccepting(item.id),
      isCaseCreated: state.isCaseCreated(item.id),
      isAlreadyTaken: state.isAlreadyTaken(item.id),
      createdCaseId: state.getCreatedCaseId(item.id),
      onAccept: () => _handleAccept(context, item),
      onDecline: () => notifier.decline(item.id),
      onViewCase: () {
        final cId = state.getCreatedCaseId(item.id) ?? item.id;
        _showCaseCreatedConfirmationDialog(context, item, cId);
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
