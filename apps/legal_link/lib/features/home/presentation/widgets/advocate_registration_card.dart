import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/shared.dart';
import '../../../onboarding/domain/advocate_application.dart';
import '../../../onboarding/domain/onboarding_providers.dart';

class AdvocateRegistrationCard extends ConsumerStatefulWidget {
  const AdvocateRegistrationCard({required this.userId, super.key});
  final String userId;

  @override
  ConsumerState<AdvocateRegistrationCard> createState() => _StatusState();
}

class _StatusState extends ConsumerState<AdvocateRegistrationCard>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      final state = ref.read(advocateApplicationProvider(widget.userId));
      if (!state.isLoading && state.value?.isVerified == false) _refresh();
    });
  }

  void _refresh() => ref.invalidate(advocateApplicationProvider(widget.userId));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(advocateApplicationProvider(widget.userId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: state.when(
          loading: () => const LegalSkeletonLoader(
            width: double.infinity,
            height: 112,
            borderRadius: 16,
          ),
          error: (_, _) => Column(
            children: [
              Text(l10n.registrationStatusError),
              const SizedBox(height: 16),
              _refreshButton(l10n),
            ],
          ),
          data: (application) =>
              _content(l10n, application, state.isRefreshing),
        ),
      ),
    );
  }

  Widget _content(
    AppLocalizations l10n,
    AdvocateApplication? app,
    bool loading,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        l10n.registrationStatusTitle,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
      _status(l10n, app),
      const SizedBox(height: 12),
      Text(_body(l10n, app)),
      if (app?.rejectionReason case final String reason
          when reason.trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(l10n.registrationRejectionReason(reason)),
      ],
      if (app != null && !app.isVerified && !app.canResubmit) ...[
        const SizedBox(height: 12),
        Text(l10n.registrationAttemptLimit),
      ],
      const SizedBox(height: 20),
      if (app == null || app.canResubmit) ...[
        AppButton.primary(
          label: app == null
              ? l10n.advocateRegistrationTitle
              : l10n.registrationEditResubmit,
          icon: const Icon(Icons.edit_document),
          isFullWidth: true,
          onPressed: () => context.push('/advocate-registration'),
        ),
        const SizedBox(height: 12),
      ],
      _refreshButton(l10n, loading: loading),
    ],
  );

  Widget _status(AppLocalizations l10n, AdvocateApplication? app) => Semantics(
    liveRegion: true,
    child: Row(
      children: [
        Icon(
          app?.isVerified == true ? Icons.verified : Icons.description_outlined,
          color: app?.isVerified == true
              ? AppColors.verifiedForest
              : AppColors.brass,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _label(l10n, app),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    ),
  );

  String _label(AppLocalizations l10n, AdvocateApplication? app) {
    if (app == null) return l10n.registrationNotSubmitted;
    if (app.isDemo) return l10n.registrationDemoComplete;
    return switch (app.verification) {
      AdvocateVerification.pending => l10n.registrationPending,
      AdvocateVerification.verified => l10n.registrationVerified,
      AdvocateVerification.rejected => l10n.registrationRejected,
    };
  }

  String _body(AppLocalizations l10n, AdvocateApplication? app) {
    if (app == null) return l10n.registrationNotSubmittedBody;
    if (app.isDemo) return l10n.registrationDemoCompleteBody;
    return switch (app.verification) {
      AdvocateVerification.pending => l10n.registrationPendingBody,
      AdvocateVerification.verified => l10n.registrationVerifiedBody,
      AdvocateVerification.rejected => l10n.registrationRejectedBody,
    };
  }

  Widget _refreshButton(AppLocalizations l10n, {bool loading = false}) =>
      AppButton.secondary(
        label: l10n.refreshAction,
        icon: const Icon(Icons.refresh),
        isFullWidth: true,
        isLoading: loading,
        onPressed: loading ? null : _refresh,
      );
}
