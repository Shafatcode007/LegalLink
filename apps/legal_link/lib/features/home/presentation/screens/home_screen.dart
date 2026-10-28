import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:legal_link/shared/shared.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/domain/app_user.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    if (user == null) return _loading();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appName)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  ..._welcome(context, l10n),
                  _profile(user, l10n),
                  const SizedBox(height: 24),
                  ..._actions(context, ref, auth, l10n),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loading() => const Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LegalSkeletonLoader(width: 88, height: 88, borderRadius: 24),
              SizedBox(height: 24),
              LegalSkeletonLoader(width: 220, height: 26, borderRadius: 8),
              SizedBox(height: 16),
              LegalSkeletonLoader(width: 320, height: 120, borderRadius: 16),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _welcome(BuildContext context, AppLocalizations l10n) => [
    Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: AppColors.oxford,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(Icons.check_rounded, size: 48, color: AppColors.white),
    ),
    const SizedBox(height: 24),
    Text(
      l10n.welcome,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 8),
    Text(
      l10n.profileComplete,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge
          ?.copyWith(color: AppColors.oxfordMuted),
    ),
    const SizedBox(height: 32),
  ];

  Widget _profile(AppUser user, AppLocalizations l10n) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.person_outline,
            label: l10n.fullName,
            value: user.fullName,
          ),
          const Divider(height: 30),
          _InfoRow(
            icon: Icons.badge_outlined,
            label: l10n.role,
            value: user.role == UserRole.client
                ? l10n.clientRole
                : l10n.advocateRole,
          ),
          const Divider(height: 30),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: l10n.phone,
            value: user.phone,
          ),
          const Divider(height: 30),
          _InfoRow(
            icon: Icons.language_rounded,
            label: l10n.language,
            value: user.language == 'bn' ? l10n.bangla : l10n.english,
          ),
        ],
      ),
    ),
  );

  List<Widget> _actions(
    BuildContext context,
    WidgetRef ref,
    AuthState auth,
    AppLocalizations l10n,
  ) => [
    if (auth.user!.role == UserRole.advocate) ...[
      AppButton.primary(
        label: l10n.advocateRegistrationTitle,
        icon: const Icon(Icons.assignment_ind_outlined),
        isFullWidth: true,
        onPressed: () => context.push('/advocate-registration'),
      ),
      const SizedBox(height: 24),
    ],
    if (auth.user!.role == UserRole.client) ...[
      TextButton.icon(
        onPressed: () => context.go('/sos'),
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        icon: const Icon(Icons.info_outline),
        label: Text(l10n.openSos),
      ),
      const SizedBox(height: 24),
    ],
    AppButton.secondary(
      label: l10n.signOut,
      icon: const Icon(Icons.logout_rounded),
      isLoading: auth.loading,
      isFullWidth: true,
      onPressed: auth.loading
          ? null
          : () => ref.read(authControllerProvider.notifier).signOut(),
    ),
    if (auth.error != null) ...[
      const SizedBox(height: 16),
      Semantics(liveRegion: true, child: Text(l10n.somethingWentWrong)),
    ],
  ];
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.brass.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.brass, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.oxfordMuted),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
