import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:legal_link/shared/shared.dart';

import '../../../../core/app_mode.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/credential_upload.dart';
import '../../domain/onboarding_providers.dart';

class CredentialUploadField extends ConsumerStatefulWidget {
  const CredentialUploadField({
    required this.userId,
    required this.kind,
    required this.label,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });
  final String userId;
  final CredentialKind kind;
  final String label;
  final bool enabled;
  final void Function(String? reference, bool busy) onChanged;
  @override
  ConsumerState<CredentialUploadField> createState() => _UploadFieldState();
}

class _UploadFieldState extends ConsumerState<CredentialUploadField> {
  CredentialFile? _file;
  UploadFailure? _error;
  String? _reference, _name;
  bool _busy = false;
  double _progress = 0;

  void _changed() => widget.onChanged(_reference, _busy);
  void _setError(Object error) => setState(
    () => _error = error is UploadFailure ? error : UploadFailure.unavailable,
  );

  Future<void> _pick() async {
    setState(() => _busy = true);
    _changed();
    try {
      final file = await ref.read(credentialPickerProvider).pick();
      if (!mounted || file == null) return;
      final failure = file.validate();
      setState(() {
        _file = failure == null ? file : null;
        _name = file.name;
        _reference = null;
        _error = failure;
      });
      if (failure == null) await _upload();
    } catch (error) {
      if (mounted) _setError(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _changed();
      }
    }
  }

  Future<void> _upload() async {
    final file = _file;
    if (file == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    _changed();
    try {
      final reference = await ref
          .read(credentialUploadRepositoryProvider)
          .upload(
            userId: widget.userId,
            kind: widget.kind,
            file: file,
            onProgress: (value) {
              if (mounted) setState(() => _progress = value.clamp(0, 1));
            },
          );
      if (mounted) {
        setState(() {
          _reference = reference;
          _file = null;
        });
      }
    } catch (error) {
      if (mounted) _setError(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _changed();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final live = ref.watch(appModeProvider) == AppMode.live;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.stone),
        borderRadius: BorderRadius.circular(16),
        color: AppColors.parchmentElevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            _name ?? l10n.uploadPhotoHint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          _UploadStatus(
            busy: _busy,
            progress: _progress,
            error: _error,
            complete: _reference != null,
            live: live,
          ),
          _actions(l10n),
        ],
      ),
    );
  }

  Widget _actions(AppLocalizations l10n) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      AppButton.secondary(
        label: _reference == null ? l10n.choosePhoto : l10n.replacePhoto,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        onPressed: widget.enabled && !_busy ? _pick : null,
      ),
      if (_error != null && _file != null)
        AppButton.secondary(
          label: l10n.retryUpload,
          icon: const Icon(Icons.refresh),
          onPressed: widget.enabled && !_busy ? _upload : null,
        ),
    ],
  );
}

class _UploadStatus extends StatelessWidget {
  const _UploadStatus({
    required this.busy,
    required this.progress,
    required this.error,
    required this.complete,
    required this.live,
  });
  final bool busy, complete, live;
  final double progress;
  final UploadFailure? error;

  String _text(AppLocalizations l10n) {
    if (busy) {
      return live
          ? l10n.uploadLiveProgress((progress * 100).round())
          : l10n.uploadProgress((progress * 100).round());
    }
    return switch (error) {
      UploadFailure.tooLarge => l10n.uploadTooLarge,
      UploadFailure.unsupportedType => l10n.uploadUnsupported,
      UploadFailure.emptyFile => l10n.uploadEmpty,
      UploadFailure.unavailable => l10n.uploadFailed,
      null =>
        complete
            ? (live ? l10n.uploadLiveReady : l10n.uploadReady)
            : l10n.uploadNotSelected,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: _height(context, l10n, constraints.maxWidth),
        child: Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (busy)
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  color: AppColors.brass,
                  backgroundColor: AppColors.stone,
                  semanticsLabel: l10n.uploading,
                  semanticsValue: '${(progress * 100).round()}%',
                ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    error != null
                        ? Icons.error_outline
                        : complete
                        ? Icons.check
                        : Icons.upload,
                    size: 24,
                    color: AppColors.brass,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_text(l10n))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _height(BuildContext context, AppLocalizations l10n, double width) {
    final messages = [
      l10n.uploadTooLarge,
      l10n.uploadUnsupported,
      l10n.uploadEmpty,
      l10n.uploadFailed,
      l10n.uploadReady,
      l10n.uploadLiveReady,
      l10n.uploadNotSelected,
      l10n.uploadProgress(100),
      l10n.uploadLiveProgress(100),
    ];
    var height = 72.0;
    for (final message in messages) {
      final painter = TextPainter(
        text: TextSpan(
          text: message,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: math.max(1, width - 32));
      height = math.max(height, painter.height + 24);
      painter.dispose();
    }
    return height;
  }
}
