import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:legal_link/shared/shared.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/sos_draft.dart';
import '../../domain/sos_providers.dart';

class ClientSosStatusPanel extends ConsumerStatefulWidget {
  const ClientSosStatusPanel({required this.request, super.key});
  final ClientSosRequest request;
  @override
  ConsumerState<ClientSosStatusPanel> createState() => _StatusState();
}

class _StatusState extends ConsumerState<ClientSosStatusPanel> {
  late ClientSosRequest _request;
  StreamSubscription<ClientSosRequest>? _subscription;
  bool _error = false, _busy = false;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    if (!_request.isDemo) _watch();
  }

  void _watch() {
    _subscription = ref
        .read(sosRepositoryProvider)
        .watch(_request.id, _request.district)
        .listen(
          (value) {
            if (mounted) {
              setState(() {
                _request = value;
                _error = false;
              });
            }
          },
          onError: (_) {
            if (mounted) setState(() => _error = true);
          },
        );
  }

  Future<void> _refresh() async {
    await _subscription?.cancel();
    if (mounted) {
      setState(() => _error = false);
      _watch();
    }
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sosCancelConfirm),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.closeAction),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.sosCancelRequest),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final value = await ref.read(sosRepositoryProvider).cancel(_request.id);
      if (mounted) setState(() => _request = value);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _title(AppLocalizations l10n) {
    if (_request.isDemo) return l10n.sosDemoComplete;
    return switch (_request.status) {
      ClientSosStatus.open => l10n.sosOpenTitle,
      ClientSosStatus.accepted => l10n.sosAcceptedTitle,
      ClientSosStatus.cancelled => l10n.sosCancelledTitle,
      ClientSosStatus.declined => l10n.sosDeclinedTitle,
      ClientSosStatus.expired => l10n.sosExpiredTitle,
    };
  }

  String _body(AppLocalizations l10n) {
    if (_request.isDemo) return l10n.sosDemoCompleteBody;
    return switch (_request.status) {
      ClientSosStatus.open => l10n.sosOpenBody,
      ClientSosStatus.accepted => l10n.sosAcceptedBody,
      _ => l10n.sosEndedBody,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _request.status == ClientSosStatus.open
                  ? Icons.campaign_outlined
                  : Icons.task_alt,
              size: 64,
              color: AppColors.brass,
            ),
            const SizedBox(height: 24),
            Text(
              _title(l10n),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(_body(l10n)),
            if (_error) _failure(l10n),
            const SizedBox(height: 24),
            ..._actions(l10n),
          ],
        ),
      ),
    );
  }

  Widget _failure(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      children: [
        const Icon(Icons.error_outline),
        Text(l10n.sosRefreshError),
        AppButton.secondary(
          label: l10n.refreshAction,
          icon: const Icon(Icons.refresh),
          onPressed: _busy ? null : _refresh,
        ),
      ],
    ),
  );

  List<Widget> _actions(AppLocalizations l10n) => [
    if (!_request.isDemo && _request.status == ClientSosStatus.open)
      AppButton.secondary(
        label: l10n.sosCancelRequest,
        icon: const Icon(Icons.cancel_outlined),
        onPressed: _busy ? null : _cancel,
        isLoading: _busy,
        isFullWidth: true,
      ),
    const SizedBox(height: 12),
    AppButton.secondary(
      label: l10n.closeAction,
      icon: const Icon(Icons.close),
      onPressed: _busy ? null : () => Navigator.pop(context),
    ),
  ];
}
