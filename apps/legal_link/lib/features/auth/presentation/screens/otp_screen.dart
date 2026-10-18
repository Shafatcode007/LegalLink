import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:legal_link/shared/shared.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/auth_controller.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final l10n = AppLocalizations.of(context);
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      setState(() {
        _errorMessage = l10n.otpLengthError;
      });

      return;
    }

    setState(() {
      _errorMessage = null;
    });

    final success = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(otp);

    if (!mounted) {
      return;
    }

    if (!success) {
      setState(() {
        _errorMessage = l10n.invalidOtp;
      });
    }

    // No manual navigation is required.
    // router.dart observes AuthState and redirects
    // to /role after successful OTP verification.
  }

  Widget _buildOtpDigit({
    required String digit,
    required bool active,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 48,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? AppColors.brass : AppColors.stone,
          width: active ? 2 : 1,
        ),
      ),
      child: Text(
        digit,
        style: const TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          color: AppColors.oxford,
        ),
      ),
    );
  }

  Widget _buildOtpBoxes() {
    final value = _otpController.text;

    return GestureDetector(
      onTap: () {
        _focusNode.requestFocus();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (index) {
          final digit = index < value.length ? value[index] : '';

          final active =
              index == value.length ||
              (value.length == 6 && index == 5);

          return _buildOtpDigit(
            digit: digit,
            active: active,
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final phone = auth.phone ?? '';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 440,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.oxford,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: AppColors.brass,
                          size: 36,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Center(
                      child: Text(
                        l10n.appName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),

                    const SizedBox(height: 44),

                    Text(
                      l10n.otpTitle,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontSize: 28,
                            height: 1.3,
                          ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      l10n.otpSubtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                            color: AppColors.oxfordMuted,
                          ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      phone,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: AppColors.brass,
                            fontWeight: FontWeight.w700,
                          ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      l10n.otpLabel,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),

                    const SizedBox(height: 12),

                    Stack(
                      children: [
                        Opacity(
                          opacity: 0,
                          child: TextFormField(
                            controller: _otpController,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _errorMessage = null;
                              });

                              if (value.length == 6 &&
                                  !auth.loading) {
                                _verifyOtp();
                              }
                            },
                          ),
                        ),

                        _buildOtpBoxes(),
                      ],
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.stone,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.brass,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.otpHelp,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        AppColors.oxfordMuted,
                                    height: 1.5,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    AppButton.primary(
                      label: l10n.verifyOtp,
                      icon: const Icon(
                        Icons.verified_outlined,
                      ),
                      onPressed:
                          auth.loading ? null : _verifyOtp,
                      isLoading: auth.loading,
                      isFullWidth: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}