import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:legal_link/shared/shared.dart';
import 'package:legal_link/shared/widgets/auth_page_frame.dart';

import '../../../../core/app_mode.dart';
import '../../../../l10n/app_localizations.dart';
import '../auth_error_localizer.dart';
import '../providers/auth_controller.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otp = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _otp.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final l10n = AppLocalizations.of(context);
    if (ref.read(authControllerProvider).loading) return;
    if (_otp.text.length != 6) {
      setState(() => _error = l10n.otpLengthError);
      return;
    }
    setState(() => _error = null);
    final success = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(_otp.text);
    if (mounted && !success) {
      setState(
        () => _error = localizedAuthError(
          l10n,
          ref.read(authControllerProvider).error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final live = ref.watch(appModeProvider) == AppMode.live;
    final error =
        _error ??
        (auth.error == null ? null : localizedAuthError(l10n, auth.error));
    return AuthPageFrame(
      appName: l10n.appName,
      icon: Icons.verified_user_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.otpTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(l10n.otpSubtitle),
          const SizedBox(height: 6),
          Text(
            auth.phone ?? '',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AppColors.brass),
          ),
          const SizedBox(height: 32),
          Text(l10n.otpLabel),
          const SizedBox(height: 12),
          _entry(l10n, auth),
          if (error != null) ...[const SizedBox(height: 10), _failure(error)],
          const SizedBox(height: 18),
          AuthHint(text: live ? l10n.liveOtpHelp : l10n.otpHelp),
          const SizedBox(height: 28),
          AppButton.primary(
            label: l10n.verifyOtp,
            icon: const Icon(Icons.verified_outlined),
            onPressed: auth.loading ? null : _verifyOtp,
            isLoading: auth.loading,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _failure(String error) => Semantics(
    liveRegion: true,
    child: AuthHint(text: error, icon: Icons.error_outline),
  );

  Widget _entry(AppLocalizations l10n, AuthState auth) => Semantics(
    textField: true,
    label: l10n.otpLabel,
    value: _otp.text,
    onTap: _focus.requestFocus,
    child: Stack(
      children: [
        Opacity(
          opacity: 0,
          child: TextFormField(
            controller: _otp,
            focusNode: _focus,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (value) {
              setState(() => _error = null);
              if (value.length == 6 && !auth.loading) _verifyOtp();
            },
          ),
        ),
        GestureDetector(
          onTap: _focus.requestFocus,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                6,
                (index) => Padding(
                  padding: EdgeInsets.only(right: index < 5 ? 8 : 0),
                  child: _digit(index),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _digit(int index) {
    final active =
        index == _otp.text.length || (_otp.text.length == 6 && index == 5);
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
        index < _otp.text.length ? _otp.text[index] : '',
        style: const TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          color: AppColors.oxford,
        ),
      ),
    );
  }
}
