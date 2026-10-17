import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_link/shared/tokens/app_colors.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

class MinimalProfileScreen extends ConsumerStatefulWidget {
  const MinimalProfileScreen({super.key});

  @override
  ConsumerState<MinimalProfileScreen> createState() =>
      _MinimalProfileScreenState();
}

class _MinimalProfileScreenState extends ConsumerState<MinimalProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _language = 'bn';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .completeProfile(
          fullName: _nameController.text.trim(),
          language: _language,
        );

    if (!mounted) {
      return;
    }

    if (success) {
      context.go('/home');
    }
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
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
                          Icons.person_outline_rounded,
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
                      l10n.profileTitle,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 28, height: 1.3),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      l10n.profileSubtitle,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: AppColors.oxfordMuted),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      l10n.fullName,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: l10n.fullNameHint,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.nameRequired;
                        }

                        if (value.trim().length < 2) {
                          return l10n.nameRequired;
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    Text(
                      l10n.verifiedPhone,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      initialValue: phone,
                      readOnly: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.verified_outlined,
                          color: AppColors.brass,
                        ),
                        suffixIcon: const Icon(Icons.lock_outline_rounded),
                        helperText: l10n.verifiedPhoneHint,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.oxfordMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.profilePrivacy,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.oxfordMuted,
                                  height: 1.4,
                                ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text(
                      l10n.language,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: _language,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.language_rounded),
                      ),
                      items: [
                        DropdownMenuItem(value: 'bn', child: Text(l10n.bangla)),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(l10n.english),
                        ),
                      ],
                      onChanged: auth.loading
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                _language = value;
                              });
                            },
                    ),

                    if (auth.error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.error
                                .withValues(alpha: 0.30),
                          ),
                        ),
                        child: Text(
                          auth.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

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
                            : Text(l10n.saveContinue),
                      ),
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
