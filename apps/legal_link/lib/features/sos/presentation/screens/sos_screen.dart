import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:legal_link/shared/shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app_mode.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/sos_draft.dart';
import '../../domain/sos_providers.dart';
import '../widgets/client_sos_status_panel.dart';

void showSosCapture(BuildContext context, String phone) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SosCaptureSheet(contactPhone: phone),
    );

class SosScreen extends ConsumerWidget {
  const SosScreen({required this.contactPhone, super.key});
  final String contactPhone;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final live = ref.watch(appModeProvider) == AppMode.live;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sosTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  Text(
                    l10n.sosSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    live ? l10n.sosLiveNotice : l10n.sosDemoNotice,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.sosHoldHint, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  const SosPhoneAction(),
                  const SizedBox(height: 24),
                  Text(
                    live ? l10n.sosLivePrivacy : l10n.sosPrivacy,
                    textAlign: TextAlign.center,
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

class SosPhoneAction extends StatelessWidget {
  const SosPhoneAction({super.key});
  Future<void> _call(BuildContext context) async {
    var launched = false;
    try {
      launched = await launchUrl(Uri(scheme: 'tel', path: '109'));
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).callUnavailable)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: AppColors.burgundy,
      side: const BorderSide(color: AppColors.burgundy),
    ),
    onPressed: () => _call(context),
    icon: const Icon(Icons.phone_outlined),
    label: Text(AppLocalizations.of(context).call109),
  );
}

class SosCaptureSheet extends ConsumerStatefulWidget {
  const SosCaptureSheet({required this.contactPhone, super.key});
  final String contactPhone;
  @override
  ConsumerState<SosCaptureSheet> createState() => _CaptureState();
}

class _CaptureState extends ConsumerState<SosCaptureSheet> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in [
      'name',
      'station',
      'district',
      'phone',
      'charges',
      'nid',
      'court',
    ])
      key: TextEditingController(),
  };
  late final _focus = {for (final key in _fields.keys) key: FocusNode()};
  late final Timer _timer;
  final _started = DateTime.now();
  final _requestId = newSosRequestId();
  DateTime? _arrestTime;
  SosUrgency _urgency = SosUrgency.high;
  bool _sending = false;
  bool _restoring = false, _restoreFailed = false;
  ClientSosFailure? _error;
  ClientSosRequest? _submitted;
  bool get _live => ref.read(appModeProvider) == AppMode.live;
  String _text(String key) => _fields[key]!.text.trim();

  @override
  void initState() {
    super.initState();
    _fields['phone']!.text = widget.contactPhone;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (_live) _restore();
  }

  Future<void> _restore() async {
    setState(() {
      _restoring = true;
      _restoreFailed = false;
    });
    try {
      final saved = await ref.read(sosRepositoryProvider).currentOpen();
      if (mounted && saved != null) {
        _timer.cancel();
        setState(() => _submitted = saved);
      }
    } catch (_) {
      if (mounted) setState(() => _restoreFailed = true);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    for (final node in _focus.values) {
      node.dispose();
    }
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<bool> _validate() async {
    final errors = _form.currentState!.validateGranularly();
    if (errors.isEmpty) return true;
    final controller = (errors.first.widget as TextFormField).controller;
    final key = _fields.entries
        .firstWhere((field) => field.value == controller)
        .key;
    _focus[key]!.requestFocus();
    await Scrollable.ensureVisible(errors.first.context, alignment: 0.2);
    return false;
  }

  SosDraft _draft() => SosDraft(
    requestId: _requestId,
    personName: _text('name'),
    policeStation: _text('station'),
    districtCourt: _text('district'),
    contactPhone: _text('phone'),
    charges: _text('charges'),
    nid: _text('nid'),
    court: _text('court'),
    arrestTime: _arrestTime,
    urgency: _urgency,
  );

  Future<void> _submit() async {
    if (!await _validate() || !mounted) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final saved = await ref.read(sosRepositoryProvider).submit(_draft());
      if (mounted) {
        _timer.cancel();
        setState(() => _submitted = saved);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ClientSosFailure
              ? error
              : ClientSosFailure.unavailable,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: FractionallySizedBox(
      heightFactor: 0.85,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _content(AppLocalizations.of(context)),
          ),
        ),
      ),
    ),
  );

  Widget _content(AppLocalizations l10n) {
    if (_restoring) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LegalSkeletonLoader(width: 220, height: 24),
          const SizedBox(height: 16),
          Text(l10n.sosPreparing),
        ],
      );
    }
    if (_restoreFailed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline),
          Text(l10n.sosRestoreError),
          const SizedBox(height: 16),
          AppButton.secondary(
            label: l10n.refreshAction,
            icon: const Icon(Icons.refresh),
            onPressed: _restore,
          ),
        ],
      );
    }
    return _submitted == null
        ? _capture(l10n)
        : ClientSosStatusPanel(request: _submitted!);
  }

  Widget _capture(AppLocalizations l10n) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sosCaptureTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(_elapsed(), style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text(_live ? l10n.sosLiveNotice : l10n.sosDemoNotice),
                const SizedBox(height: 24),
                ..._requiredFields(l10n),
                _optionalFields(l10n),
                if (_error != null) _errorMessage(l10n),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_sending)
          Semantics(liveRegion: true, child: Text(l10n.sosPreparing)),
        _sendButton(l10n),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: Text(l10n.cancelAction),
        ),
      ],
    ),
  );

  String _elapsed() {
    final duration = DateTime.now().difference(_started);
    return '${duration.inMinutes.toString().padLeft(2, '0')}:'
        '${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  List<Widget> _requiredFields(AppLocalizations l10n) => [
    _field('name', l10n.personName),
    _field('station', l10n.policeStation),
    _field('district', l10n.districtCourt),
    _field(
      'phone',
      l10n.contactPhone,
      keyboard: TextInputType.phone,
      validator: (value) =>
          SosDraft.validPhone(value!.trim()) ? null : l10n.invalidPhone,
    ),
  ];

  Widget _optionalFields(AppLocalizations l10n) => ExpansionTile(
    title: Text(l10n.sosDetails),
    tilePadding: EdgeInsets.zero,
    children: [
      _field('charges', l10n.chargesOptional, required: false),
      _field('court', l10n.courtOptional, required: false),
      _field(
        'nid',
        l10n.nidOptional,
        required: false,
        keyboard: TextInputType.number,
        validator: (value) =>
            value!.isEmpty ||
                RegExp(r'^(?:[0-9]{10}|[0-9]{13}|[0-9]{17})$').hasMatch(value)
            ? null
            : l10n.nidValidation,
      ),
      _urgencyField(l10n),
      const SizedBox(height: 16),
      _timeActions(l10n),
    ],
  );

  Widget _urgencyField(
    AppLocalizations l10n,
  ) => DropdownButtonFormField<SosUrgency>(
    initialValue: _urgency,
    decoration: InputDecoration(labelText: l10n.urgencyLabel),
    items: [
      DropdownMenuItem(value: SosUrgency.high, child: Text(l10n.urgencyHigh)),
      DropdownMenuItem(
        value: SosUrgency.critical,
        child: Text(l10n.urgencyCritical),
      ),
    ],
    onChanged: _sending ? null : (value) => setState(() => _urgency = value!),
  );

  Widget _timeActions(AppLocalizations l10n) => Column(
    children: [
      AppButton.secondary(
        label: l10n.arrestTimeOptional,
        icon: const Icon(Icons.schedule),
        onPressed: _sending ? null : _pickArrestTime,
        isFullWidth: true,
      ),
      if (_arrestTime != null) ...[
        Text(
          '${MaterialLocalizations.of(context).formatShortDate(_arrestTime!)} '
          '${TimeOfDay.fromDateTime(_arrestTime!).format(context)}',
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _sending ? null : () => setState(() => _arrestTime = null),
          child: Text(l10n.clearArrestTime),
        ),
      ],
    ],
  );

  Future<void> _pickArrestTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDate: _arrestTime ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_arrestTime ?? now),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).arrestTimeFuture)),
      );
    } else {
      setState(() => _arrestTime = selected);
    }
  }

  Widget _errorMessage(AppLocalizations l10n) => Semantics(
    liveRegion: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: AppColors.oxford),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _error == ClientSosFailure.rateLimited
                ? l10n.sosRateLimited
                : _live
                ? l10n.sosLiveError
                : l10n.sosSendError,
          ),
        ),
      ],
    ),
  );

  Widget _sendButton(AppLocalizations l10n) => AppButton.primary(
    label: _error != null
        ? (_live ? l10n.sosLiveRetry : l10n.sosRetry)
        : (_live ? l10n.sosLiveSend : l10n.sosSend),
    icon: const Icon(Icons.send_outlined),
    isLoading: _sending,
    isFullWidth: true,
    onPressed: _sending ? null : _submit,
  );

  Widget _field(
    String key,
    String label, {
    bool required = true,
    TextInputType? keyboard,
    FormFieldValidator<String>? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: TextFormField(
      controller: _fields[key],
      focusNode: _focus[key],
      enabled: !_sending,
      keyboardType: keyboard,
      inputFormatters: keyboard == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        labelText: label,
        errorMaxLines: 3,
        constraints: const BoxConstraints(minHeight: 52),
      ),
      textInputAction: TextInputAction.next,
      validator:
          validator ??
          (value) => required && (value == null || value.trim().isEmpty)
              ? AppLocalizations.of(context).fieldRequired
              : null,
    ),
  );
}
