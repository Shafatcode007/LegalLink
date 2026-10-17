import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:legal_link/shared/tokens/app_colors.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/user_role.dart';
import '../providers/auth_controller.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final auth = ref.watch(authControllerProvider);

    final controller = ref.read(authControllerProvider.notifier);

    void selectRole(UserRole role) {
      controller.selectRole(role);
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
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
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),

                  const SizedBox(height: 44),

                  Text(
                    l10n.roleTitle,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontSize: 28, height: 1.3),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    l10n.roleSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: AppColors.oxfordMuted),
                  ),

                  const SizedBox(height: 28),

                  _RoleCard(
                    selected: auth.role == UserRole.client,
                    icon: Icons.person_outline_rounded,
                    title: l10n.clientRole,
                    description: l10n.clientRoleDescription,
                    onTap: () {
                      selectRole(UserRole.client);
                    },
                  ),

                  const SizedBox(height: 16),

                  _RoleCard(
                    selected: auth.role == UserRole.advocate,
                    icon: Icons.gavel_rounded,
                    title: l10n.advocateRole,
                    description: l10n.advocateRoleDescription,
                    onTap: () {
                      selectRole(UserRole.advocate);
                    },
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

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: auth.role == null
                          ? null
                          : () {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .confirmRole();
                            },
                      child: Text(l10n.continueText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brass.withValues(alpha: 0.08)
              : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.brass : AppColors.stone,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected ? AppColors.brass : AppColors.oxford,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.white, size: 27),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.oxfordMuted, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.brass : AppColors.stone,
            ),
          ],
        ),
      ),
    );
  }
}
