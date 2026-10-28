import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:legal_link/shared/shared.dart';
import 'package:legal_link/shared/widgets/auth_page_frame.dart';

import '../../../../l10n/app_localizations.dart';
import '../auth_error_localizer.dart';
import '../providers/auth_controller.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});
  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value, AppLocalizations l10n) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^1[3-9][0-9]{8}$').hasMatch(digits)
        ? null
        : l10n.invalidPhone;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .sendOtp('+880${_phone.text.replaceAll(RegExp(r'\D'), '')}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    return AuthPageFrame(
      appName: l10n.appName,
      icon: Icons.balance_rounded,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.phoneTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(l10n.phoneSubtitle),
            const SizedBox(height: 28),
            Text(
              l10n.phoneLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _phoneField(l10n, auth),
            const SizedBox(height: 12),
            AuthHint(text: l10n.phonePrivacy, icon: Icons.lock_outline),
            const SizedBox(height: 28),
            AppButton.primary(
              label: l10n.sendOtp,
              icon: const Icon(Icons.sms_outlined),
              onPressed: auth.loading || auth.initializing ? null : _submit,
              isLoading: auth.loading,
              isFullWidth: true,
            ),
            if (auth.error != null) ...[
              const SizedBox(height: 16),
              _failure(l10n, auth.error),
            ],
          ],
        ),
      ),
    );
  }

  Widget _failure(AppLocalizations l10n, String? error) => Semantics(
    liveRegion: true,
    child: AuthHint(
      icon: Icons.error_outline,
      text: localizedAuthError(l10n, error),
    ),
  );

  Widget _phoneField(AppLocalizations l10n, AuthState auth) => TextFormField(
    controller: _phone,
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
      constraints: const BoxConstraints(minHeight: 52),
    ),
    validator: (value) => _validatePhone(value, l10n),
    onFieldSubmitted: (_) {
      if (!auth.loading && !auth.initializing) _submit();
    },
  );
}
