import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_mode.dart';
import '../features/sos/presentation/screens/sos_screen.dart';
import '../features/sos/presentation/widgets/hold_to_confirm_sos_button.dart';
import '../l10n/app_localizations.dart';

class ClientShell extends ConsumerWidget {
  const ClientShell({
    required this.child,
    required this.phone,
    required this.expanded,
    super.key,
  });
  final Widget child;
  final String phone;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final live = ref.watch(appModeProvider) == AppMode.live;
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: child),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: HoldToConfirmSosButton(
                compact: !expanded,
                confirmationBody: live
                    ? l10n.sosConfirmBodyLive
                    : l10n.sosConfirmBody,
                onConfirmed: () => showSosCapture(context, phone),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
