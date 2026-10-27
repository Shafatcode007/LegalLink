import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:legal_link/shared/shared.dart';

import '../../../../core/app_mode.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/advocate_registration.dart';
import '../../domain/credential_upload.dart';
import '../../domain/onboarding_providers.dart';
import '../widgets/credential_upload_field.dart';

class AdvocateRegistrationScreen extends ConsumerStatefulWidget {
  const AdvocateRegistrationScreen({required this.userId, super.key});
  final String userId;
  @override
  ConsumerState<AdvocateRegistrationScreen> createState() =>
      _RegistrationState();
}

class _RegistrationState extends ConsumerState<AdvocateRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fields = {
    for (final key in [
      'nid',
      'bar',
      'courts',
      'districts',
      'min',
      'max',
      'years',
      'pin',
      'confirm',
    ])
      key: TextEditingController(),
  };
  late final _focus = {for (final key in _fields.keys) key: FocusNode()};
  final _specializations = <Specialization>{};
  final _languages = <String>{'bn'};
  final _documents = <CredentialKind, String?>{};
  final _busyDocuments = <CredentialKind>{};
  bool _saving = false, _submitted = false, _showErrors = false;
  bool _available = true;
  RegistrationFailure? _failure;

  bool get _live => ref.read(appModeProvider) == AppMode.live;
  String _text(String key) => _fields[key]!.text.trim();
  List<String> _list(String key) =>
      _text(key)
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<bool> _validate() async {
    setState(() => _showErrors = true);
    final errors = _formKey.currentState!.validateGranularly();
    if (errors.isNotEmpty) {
      final controller = (errors.first.widget as TextFormField).controller;
      final key = _fields.entries
          .firstWhere((item) => item.value == controller)
          .key;
      _focus[key]!.requestFocus();
      await Scrollable.ensureVisible(errors.first.context, alignment: 0.2);
      return false;
    }
    return _specializations.isNotEmpty &&
        _languages.isNotEmpty &&
        _documents[CredentialKind.sanad] != null &&
        _documents[CredentialKind.nid] != null;
  }

  AdvocateRegistration _application() => AdvocateRegistration(
    nid: _text('nid'),
    barCouncilNumber: _text('bar'),
    courts: _list('courts'),
    districts: _list('districts'),
    specializations: Set.of(_specializations),
    feeMin: int.parse(_text('min')),
    feeMax: int.parse(_text('max')),
    languages: Set.of(_languages),
    pin: _text('pin'),
    yearsPractice: int.parse(_text('years')),
    availableForSos: _available,
    sanadReference: _documents[CredentialKind.sanad]!,
    nidReference: _documents[CredentialKind.nid]!,
    avatarReference: _documents[CredentialKind.avatar],
  );

  Future<void> _submit() async {
    if (!await _validate() || !mounted) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(advocateRegistrationRepositoryProvider)
          .submit(widget.userId, _application());
      if (mounted) {
        _fields['pin']!.clear();
        _fields['confirm']!.clear();
        setState(() => _submitted = true);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _failure = error is RegistrationFailure
              ? error
              : RegistrationFailure.unavailable,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.advocateRegistrationTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _submitted ? _completion(l10n) : _form(l10n),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(AppLocalizations l10n) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.advocateRegistrationSubtitle),
        const SizedBox(height: 16),
        _feedback(
          _live ? l10n.registrationLiveNotice : l10n.registrationDemoNotice,
        ),
        const SizedBox(height: 40),
        ..._identity(l10n),
        ..._practice(l10n),
        ..._pinFields(l10n),
        const SizedBox(height: 40),
        ..._documentFields(l10n),
        if (_failure != null) _feedback(_failureText(l10n), error: true),
        const SizedBox(height: 32),
        _submitButton(l10n),
      ],
    ),
  );

  List<Widget> _identity(AppLocalizations l10n) => [
    _field(
      'nid',
      l10n.nidNumber,
      numeric: true,
      validator: (value) => AdvocateRegistration.validNid(value!.trim())
          ? null
          : l10n.nidValidation,
    ),
    _field('bar', l10n.barCouncilNumber),
    _field(
      'courts',
      l10n.courtsLabel,
      hint: l10n.courtsHint,
      validator: (_) => _list('courts').isEmpty ? l10n.fieldRequired : null,
    ),
    _field(
      'districts',
      l10n.districtsLabel,
      hint: l10n.districtsHint,
      validator: (_) => _list('districts').isEmpty ? l10n.fieldRequired : null,
    ),
    _field(
      'years',
      l10n.yearsPracticeLabel,
      numeric: true,
      validator: (value) {
        final years = int.tryParse(value ?? '');
        return years != null && years >= 0 && years <= 80
            ? null
            : l10n.yearsPracticeValidation;
      },
    ),
  ];

  List<Widget> _practice(AppLocalizations l10n) => [
    Text(
      l10n.specializationsLabel,
      style: Theme.of(context).textTheme.titleMedium,
    ),
    const SizedBox(height: 8),
    _specializationChips(l10n),
    if (_showErrors && _specializations.isEmpty)
      _feedback(l10n.specializationRequired, error: true),
    const SizedBox(height: 24),
    ..._fees(l10n),
    ..._languageFields(l10n),
    SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.availabilityLabel),
      value: _available,
      activeThumbColor: AppColors.brass,
      onChanged: _saving ? null : (value) => setState(() => _available = value),
    ),
    const SizedBox(height: 24),
  ];

  List<Widget> _fees(AppLocalizations l10n) => [
    _field(
      'min',
      l10n.feeMinLabel,
      numeric: true,
      validator: (value) => _validFee(value) ? null : l10n.feeValidation,
    ),
    _field(
      'max',
      l10n.feeMaxLabel,
      numeric: true,
      validator: (value) {
        final min = int.tryParse(_text('min'));
        final max = int.tryParse(value ?? '');
        return _validFee(value) && min != null && max! >= min
            ? null
            : l10n.feeValidation;
      },
    ),
  ];

  bool _validFee(String? value) {
    final amount = int.tryParse(value ?? '');
    return amount != null && amount >= 0 && amount <= 9999999999;
  }

  Widget _specializationChips(AppLocalizations l10n) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final value in Specialization.values)
        _chip(
          _specializationLabel(l10n, value),
          _specializations.contains(value),
          (selected) => setState(() {
            selected
                ? _specializations.add(value)
                : _specializations.remove(value);
          }),
        ),
    ],
  );

  List<Widget> _languageFields(AppLocalizations l10n) => [
    Text(l10n.spokenLanguages, style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in {'bn': l10n.bangla, 'en': l10n.english}.entries)
          _chip(
            entry.value,
            _languages.contains(entry.key),
            (selected) => setState(() {
              selected
                  ? _languages.add(entry.key)
                  : _languages.remove(entry.key);
            }),
          ),
      ],
    ),
    if (_showErrors && _languages.isEmpty)
      _feedback(l10n.languageRequired, error: true),
    const SizedBox(height: 24),
  ];

  List<Widget> _pinFields(AppLocalizations l10n) => [
    _feedback(l10n.approvalPinHint),
    const SizedBox(height: 16),
    _field(
      'pin',
      l10n.approvalPinLabel,
      numeric: true,
      obscure: true,
      validator: (value) => RegExp(r'^[0-9]{4}$').hasMatch(value ?? '')
          ? null
          : l10n.pinValidation,
    ),
    _field(
      'confirm',
      l10n.confirmApprovalPin,
      numeric: true,
      obscure: true,
      validator: (value) =>
          value == _text('pin') && value!.length == 4 ? null : l10n.pinMismatch,
    ),
  ];

  List<Widget> _documentFields(AppLocalizations l10n) => [
    _document(CredentialKind.sanad, l10n.sanadPhoto),
    const SizedBox(height: 24),
    _document(CredentialKind.nid, l10n.nidPhoto),
    const SizedBox(height: 24),
    _document(CredentialKind.avatar, l10n.profilePhotoLabel),
    if (_showErrors &&
        (_documents[CredentialKind.sanad] == null ||
            _documents[CredentialKind.nid] == null))
      _feedback(l10n.documentsRequired, error: true),
    const SizedBox(height: 24),
  ];

  Widget _document(CredentialKind kind, String label) => CredentialUploadField(
    key: ValueKey(kind),
    userId: widget.userId,
    kind: kind,
    label: label,
    enabled: !_saving,
    onChanged: (reference, busy) => setState(() {
      _documents[kind] = reference;
      busy ? _busyDocuments.add(kind) : _busyDocuments.remove(kind);
    }),
  );

  Widget _submitButton(AppLocalizations l10n) => AppButton.primary(
    label: _live ? l10n.registrationSubmitLive : l10n.submitRegistration,
    icon: const Icon(Icons.assignment_turned_in_outlined),
    onPressed: _saving || _busyDocuments.isNotEmpty ? null : _submit,
    isLoading: _saving,
    isFullWidth: true,
  );

  Widget _completion(AppLocalizations l10n) => Semantics(
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.task_alt, size: 64, color: AppColors.brass),
        const SizedBox(height: 24),
        Text(
          _live ? l10n.registrationSubmitted : l10n.registrationDemoComplete,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Text(
          _live
              ? l10n.registrationSubmittedBody
              : l10n.registrationDemoCompleteBody,
        ),
      ],
    ),
  );

  String _failureText(AppLocalizations l10n) => switch (_failure) {
    RegistrationFailure.attemptsExhausted => l10n.registrationAttemptLimit,
    RegistrationFailure.pinProtected => l10n.registrationPinProtected,
    _ => l10n.registrationSaveError,
  };

  String _specializationLabel(AppLocalizations l10n, Specialization value) =>
      switch (value) {
        Specialization.criminal => l10n.specializationCriminal,
        Specialization.bail => l10n.specializationBail,
        Specialization.family => l10n.specializationFamily,
        Specialization.property => l10n.specializationProperty,
        Specialization.labor => l10n.specializationLabor,
        Specialization.womenAndChild => l10n.specializationWomenChild,
      };

  Widget _feedback(String text, {bool error = false}) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.error_outline : Icons.info_outline,
            color: AppColors.oxford,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );

  Widget _chip(String label, bool selected, ValueChanged<bool> changed) =>
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: FilterChip(
          label: Text(label),
          selected: selected,
          selectedColor: AppColors.brassWash,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onSelected: _saving ? null : changed,
        ),
      );

  Widget _field(
    String key,
    String label, {
    bool numeric = false,
    bool obscure = false,
    String? hint,
    FormFieldValidator<String>? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: TextFormField(
      controller: _fields[key],
      focusNode: _focus[key],
      enabled: !_saving,
      obscureText: obscure,
      enableSuggestions: !obscure,
      autocorrect: !obscure,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        errorMaxLines: 3,
        constraints: const BoxConstraints(minHeight: 52),
      ),
      validator:
          validator ??
          (value) => value == null || value.trim().isEmpty
              ? AppLocalizations.of(context).fieldRequired
              : null,
    ),
  );
}
