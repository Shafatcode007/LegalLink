import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:legal_link/shared/tokens/app_colors.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/auth_controller.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _formKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');

    return '+880$digits';
  }

  String? _validatePhone(String? value, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.invalidPhone;
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');

    final validPhone = RegExp(r'^1[3-9]\d{8}$');

    if (!validPhone.hasMatch(digits)) {
      return l10n.invalidPhone;
    }

    return null;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final phone = _normalizePhone(_phoneController.text.trim());

    final success = await ref
        .read(authControllerProvider.notifier)
        .sendOtp(phone);

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.somethingWentWrong)));
    }

    // No manual navigation is required here.
    // router.dart observes AuthState.
    // When phone becomes non-null,
    // GoRouter redirects to /otp.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
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
                          Icons.balance_rounded,
                          color: AppColors.brass,
                          size: 38,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Center(
                      child: Text(
                        l10n.appName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),

                    const SizedBox(height: 44),

                    Text(
                      l10n.phoneTitle,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 28, height: 1.3),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      l10n.phoneSubtitle,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: AppColors.oxfordMuted),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      l10n.phoneLabel,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        prefixText: '+880  ',
                        hintText: l10n.phoneHint,
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      validator: (value) => _validatePhone(value, l10n),
                      onFieldSubmitted: (_) {
                        if (!auth.loading) {
                          _submit();
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.lock_outline_rounded,
                            size: 17,
                            color: AppColors.oxfordMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.phonePrivacy,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.oxfordMuted,
                                  height: 1.5,
                                ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: auth.loading ? null : _submit,
                        child: auth.loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : Text(l10n.sendOtp),
                      ),
                    ),

                    if (auth.error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        auth.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
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
