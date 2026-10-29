import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/shared.dart';
import '../../domain/entities/sos_request_item.dart';
import '../notifiers/sos_form_notifier.dart';

/// Client SOS Broadcast Form Screen (Sprint 2, Role B2).
///
/// Implements:
/// 1. 4 required minimal capture fields (ui_ux.md §3.3):
///    - Arrested Person Name
///    - Thana
///    - District / Court
///    - Contact Phone Number
/// 2. Collapsible optional details (Charges, Notes, Urgency).
/// 3. SyncBadge alongside offline and queued UI states (Task 4, PRD F8, ui_ux.md §4.3).
/// 4. Court-basement offline queueing with 50/100 op warning banners.
/// 5. Emergency 109 government hotline quick call prompt.
/// 6. Full-screen Broadcasting state with Brass arc loader (no generic spinners).
class SosBroadcastFormScreen extends ConsumerStatefulWidget {
  const SosBroadcastFormScreen({super.key});

  @override
  ConsumerState<SosBroadcastFormScreen> createState() =>
      _SosBroadcastFormScreenState();
}

class _SosBroadcastFormScreenState extends ConsumerState<SosBroadcastFormScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _thanaController;
  late final TextEditingController _courtController;
  late final TextEditingController _phoneController;
  late final TextEditingController _chargesController;
  late final TextEditingController _notesController;

  bool _isDetailsExpanded = false;
  late AnimationController _holdController;

  @override
  void initState() {
    super.initState();
    final formState = ref.read(sosFormProvider);
    _nameController = TextEditingController(text: formState.personName);
    _thanaController = TextEditingController(text: formState.thana);
    _courtController = TextEditingController(text: formState.court);
    _phoneController = TextEditingController(text: formState.contactPhone);
    _chargesController = TextEditingController(text: formState.charges);
    _notesController = TextEditingController(text: formState.notes);

    // 600ms hold-to-confirm timer controller per ui_ux.md §1.4.2
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.mediumImpact();
        ref.read(sosFormProvider.notifier).submitSos();
        _holdController.reset();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _thanaController.dispose();
    _courtController.dispose();
    _phoneController.dispose();
    _chargesController.dispose();
    _notesController.dispose();
    _holdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(sosFormProvider);
    final notifier = ref.read(sosFormProvider.notifier);

    // If live broadcast is active, show the broadcasting state per ui_ux.md §3.3
    if (formState.isBroadcastActive) {
      return _buildBroadcastingState(context, formState, notifier);
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
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.burgundy,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'জরুরি SOS পাঠান',
              style: AppTypography.displayHeading(fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Offline mode simulation switch (for court-basement testing)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formState.isOffline ? 'অফলাইন' : 'অনলাইন',
                  style: AppTypography.caption(
                    color: formState.isOffline
                        ? AppColors.stoneText
                        : AppColors.verifiedForest,
                  ),
                ),
                Switch.adaptive(
                  value: formState.isOffline,
                  activeTrackColor: AppColors.stoneText,
                  onChanged: (val) => notifier.toggleOffline(val),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SyncBadge banner reflecting current sync and queue status (Task 4)
              SyncBadge(
                status: formState.syncStatus,
                pendingCount: formState.pendingQueueCount,
                isBanner: true,
                onTap: formState.pendingQueueCount > 0
                    ? () => notifier.syncPendingQueue()
                    : null,
              ),
              const SizedBox(height: 14),

              // 2. Government 109 emergency hotline quick call prompt (ui_ux.md §3.3)
              _buildGovHotlineBanner(context),
              const SizedBox(height: 16),

              // Reassurance note
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brassWash,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.brass, width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: AppColors.brass,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'আপনার নাম ও ঠিকানা শুধু যাচাইকৃত উকিলরা দেখতে পাবেন।',
                        style: AppTypography.caption(color: AppColors.oxford)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Four Minimal Required Fields (ui_ux.md §3.3)
              Text(
                'আবশ্যকীয় তথ্য (Required)',
                style: AppTypography.displayHeading(fontSize: 16),
              ),
              const SizedBox(height: 12),

              // Field 1: Arrested Person Name
              _buildInputField(
                label: 'আটককৃত ব্যক্তির নাম *',
                hint: 'উদাঃ মোঃ রফিকুল ইসলাম',
                icon: Icons.person_outline_rounded,
                controller: _nameController,
                onChanged: notifier.updatePersonName,
              ),
              const SizedBox(height: 14),

              // Field 2: Thana
              _buildInputField(
                label: 'থানা (Thana) *',
                hint: 'উদাঃ ধানমন্ডি মডেল থানা',
                icon: Icons.local_police_outlined,
                controller: _thanaController,
                onChanged: notifier.updateThana,
              ),
              const SizedBox(height: 14),

              // Field 3: District / Court with location helper chip
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'জেলা / আদালত *',
                        style: AppTypography.caption(
                          color: AppColors.oxfordMuted,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      GestureDetector(
                        onTap: () {
                          _courtController.text = 'ঢাকা মহানগর দায়রা জজ আদালত';
                          notifier.updateDistrict('ঢাকা');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brassWash,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.brass,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.my_location_rounded,
                                size: 12,
                                color: AppColors.brass,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'অবস্থান অনুযায়ী (From GPS)',
                                style: AppTypography.caption(
                                  fontSize: 11,
                                  color: AppColors.brass,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildRawInput(
                    hint: 'উদাঃ ঢাকা মহানগর দায়রা জজ আদালত',
                    icon: Icons.gavel_outlined,
                    controller: _courtController,
                    onChanged: (val) {
                      notifier.updateDistrict(val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Field 4: Contact Phone Number
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'জরুরি যোগাযোগের ফোন নম্বর *',
                    style: AppTypography.caption(color: AppColors.oxfordMuted)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.brassWash,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.stone,
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          '+880',
                          style: AppTypography.uiBody(
                            fontWeight: FontWeight.w700,
                            color: AppColors.oxford,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildRawInput(
                          hint: '1712345678',
                          icon: Icons.phone_android_rounded,
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          onChanged: notifier.updateContactPhone,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 4. Optional Collapsible Details (ui_ux.md §3.3)
              Material(
                color: AppColors.parchmentElevated,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: AppColors.stone, width: 0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: AppColors.brass,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'বিস্তারিত তথ্য (Optional Details)',
                          style: AppTypography.banglaBody(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.oxford,
                          ),
                        ),
                      ],
                    ),
                    initiallyExpanded: _isDetailsExpanded,
                    onExpansionChanged: (val) =>
                        setState(() => _isDetailsExpanded = val),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputField(
                              label: 'অভিযোগ বা ধারা',
                              hint: 'উদাঃ ফৌজদারি কার্যবিধি ৫৪ ধারা',
                              icon: Icons.description_outlined,
                              controller: _chargesController,
                              onChanged: notifier.updateCharges,
                            ),
                            const SizedBox(height: 12),
                            _buildInputField(
                              label: 'অতিরিক্ত বিবরণ / নোট',
                              hint: 'ঘটনাস্থল বা প্রয়োজনীয় বিশেষ তথ্য...',
                              icon: Icons.notes_rounded,
                              controller: _notesController,
                              maxLines: 2,
                              onChanged: notifier.updateNotes,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'জরুরিতার মাত্রা',
                              style: AppTypography.caption(
                                color: AppColors.oxfordMuted,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _buildUrgencyChip(
                                  label: 'উচ্চ (High)',
                                  urgency: SosUrgency.high,
                                  selected:
                                      formState.urgency == SosUrgency.high,
                                  onSelected: () =>
                                      notifier.updateUrgency(SosUrgency.high),
                                ),
                                const SizedBox(width: 8),
                                _buildUrgencyChip(
                                  label: 'সংকটজনক (Critical)',
                                  urgency: SosUrgency.critical,
                                  selected:
                                      formState.urgency == SosUrgency.critical,
                                  onSelected: () => notifier.updateUrgency(
                                    SosUrgency.critical,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Error banner if any
              if (formState.errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.burgundyWash,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.burgundy, width: 1.0),
                  ),
                  child: Text(
                    formState.errorMessage!,
                    style: AppTypography.caption(color: AppColors.burgundy)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Reassurance above CTA
              Center(
                child: Text(
                  formState.isOffline
                      ? 'অফলাইনে সংরক্ষণের পর সংযোগ পেলেই ১২ জন উকিলকে জানানো হবে।'
                      : 'আপনার থানার ১২ জন যাচাইকৃত উকিলকে জানানো হবে।',
                  style: AppTypography.caption(color: AppColors.oxfordMuted),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),

              // 5. Broadcast CTA with 600ms Hold-to-Confirm Gesture (ui_ux.md §1.4.2)
              _buildHoldToBroadcastButton(context, formState, notifier),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGovHotlineBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.parchmentElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.burgundy, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.phone_in_talk_rounded,
                size: 18,
                color: AppColors.burgundy,
              ),
              const SizedBox(width: 8),
              Text(
                'সরকারি জরুরি সহায়তা ১০৯',
                style: AppTypography.banglaBody(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.burgundy,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.burgundy,
                  content: Text('১০৯ নম্বরে ডায়াল করা হচ্ছে...'),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.burgundyWash,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.burgundy, width: 0.8),
              ),
              child: Text(
                'কল করুন (Call 109)',
                style: AppTypography.caption(
                  fontSize: 11,
                  color: AppColors.burgundy,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption(color: AppColors.oxfordMuted)
              .copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        _buildRawInput(
          hint: hint,
          icon: icon,
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildRawInput({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    ValueChanged<String>? onChanged,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.parchmentElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.stone, width: 1.0),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: AppTypography.uiBody(color: AppColors.oxford),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTypography.caption(color: AppColors.stoneText),
          prefixIcon: Icon(icon, size: 20, color: AppColors.brass),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildUrgencyChip({
    required String label,
    required SosUrgency urgency,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: AppTypography.caption(
          color: selected ? AppColors.parchment : AppColors.oxford,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
      selected: selected,
      selectedColor: urgency == SosUrgency.critical
          ? AppColors.burgundy
          : AppColors.brass,
      backgroundColor: AppColors.parchmentElevated,
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildHoldToBroadcastButton(
    BuildContext context,
    SosFormState formState,
    SosFormNotifier notifier,
  ) {
    if (formState.isSubmitting) {
      return Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.brassWash,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.brass, width: 1.2),
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BrassArcLoader(size: 20),
            SizedBox(width: 10),
            Text('প্রক্রিয়াকরণ হচ্ছে...'),
          ],
        ),
      );
    }

    // Interactive button with 600ms hold gesture
    return GestureDetector(
      onTapDown: (_) {
        if (!formState.isSubmitting) {
          _holdController.forward();
        }
      },
      onTapUp: (_) {
        if (_holdController.status != AnimationStatus.completed) {
          _holdController.reverse();
        }
      },
      onTapCancel: () {
        _holdController.reverse();
      },
      child: AnimatedBuilder(
        animation: _holdController,
        builder: (context, child) {
          final progress = _holdController.value;
          final isHolding = progress > 0.0;

          return Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              color: formState.isOffline
                  ? AppColors.oxford
                  : AppColors.burgundy,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHolding ? AppColors.brass : Colors.transparent,
                width: 2.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F000000),
                  offset: Offset(0, 3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Progress fill for 600ms hold
                if (isHolding)
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.brass.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        formState.isOffline
                            ? Icons.save_alt_rounded
                            : Icons.crisis_alert_rounded,
                        color: AppColors.parchment,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isHolding
                            ? 'ধরে রাখুন... (${(progress * 100).toInt()}%)'
                            : formState.isOffline
                            ? 'অফলাইনে জমা দিন (Queue Offline)'
                            : 'SOS পাঠান (Hold 600ms to send)',
                        style: AppTypography.uiBody(
                          fontWeight: FontWeight.w700,
                          color: AppColors.parchment,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 6. Full-screen Broadcasting State per ui_ux.md §3.3 & §4.2:
  /// Brass arc circling burgundy SOS glyph, live advocate counter, cancel link.
  Widget _buildBroadcastingState(
    BuildContext context,
    SosFormState formState,
    SosFormNotifier notifier,
  ) {
    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Circular SOS glyph circled by BrassArcLoader
              Stack(
                alignment: Alignment.center,
                children: [
                  const BrassArcLoader(size: 160, strokeWidth: 4),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      color: AppColors.burgundy,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x337A2230),
                          offset: Offset(0, 6),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.crisis_alert_rounded,
                          color: AppColors.parchment,
                          size: 44,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'SOS',
                          style: TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                            color: AppColors.parchment,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Text(
                'SOS সম্প্রচার হচ্ছে...',
                style: AppTypography.displayHeading(
                  fontSize: 24,
                  color: AppColors.burgundy,
                ),
              ),
              const SizedBox(height: 8),

              // Live advocate ticker
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brassWash,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.brass, width: 0.8),
                ),
                child: Text(
                  '${formState.notifiedAdvocatesCount} জন যাচাইকৃত উকিলকে জানানো হয়েছে',
                  style: AppTypography.banglaBody(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.oxford,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'আপনার থানার নিকটতম আইনজীবীদের কাছে জরুরি বার্তা পৌঁছেছে। একজন আইনজীবী গ্রহণ করলেই আপনাকে কল দেওয়া হবে।',
                style: AppTypography.banglaBody(
                  fontSize: 16,
                  color: AppColors.oxfordMuted,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Quick call 109 link while waiting
              _buildGovHotlineBanner(context),
              const SizedBox(height: 16),

              // Tertiary cancel button
              TextButton(
                onPressed: () {
                  // Cancel broadcast
                  notifier.toggleOffline(false);
                },
                child: Text(
                  'SOS বাতিল করুন (Cancel SOS)',
                  style: AppTypography.caption(color: AppColors.oxfordMuted)
                      .copyWith(decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
