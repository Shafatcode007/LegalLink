import 'package:flutter/material.dart';

import '../../../../shared/shared.dart';
import '../../domain/entities/advocate_verification_item.dart';

/// Modal dialog for reviewing uploaded advocate verification documents via secure temporary signed URLs.
///
/// Features:
/// - Enforces 15-minute signed URL visibility per ADR-011 (no public storage URLs)
/// - Visual expiration badge and refresh capability
/// - Preview rendering with full-screen zoom dialog support (InteractiveViewer)
/// - Breathing gavel loader while signed URL or image resolves
/// - Rejection / Approval actions directly from preview modal
class DocumentPreviewDialog extends StatefulWidget {
  const DocumentPreviewDialog({
    super.key,
    required this.advocate,
    this.isNid = false,
    this.onApprove,
    this.onReject,
    this.onRefreshSignedUrl,
  });

  final AdvocateVerificationItem advocate;
  final bool isNid;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final Future<void> Function()? onRefreshSignedUrl;

  static Future<void> show(
    BuildContext context, {
    required AdvocateVerificationItem advocate,
    bool isNid = false,
    VoidCallback? onApprove,
    VoidCallback? onReject,
    Future<void> Function()? onRefreshSignedUrl,
  }) {
    return showDialog(
      context: context,
      barrierColor: AppColors.oxford.withValues(alpha: 0.65),
      builder: (_) => DocumentPreviewDialog(
        advocate: advocate,
        isNid: isNid,
        onApprove: onApprove,
        onReject: onReject,
        onRefreshSignedUrl: onRefreshSignedUrl,
      ),
    );
  }

  @override
  State<DocumentPreviewDialog> createState() => _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState extends State<DocumentPreviewDialog> {
  bool _isRefreshing = false;

  String? get _signedUrl => widget.isNid
      ? (widget.advocate.nidSignedUrl ?? widget.advocate.nidUrl)
      : (widget.advocate.sanadSignedUrl ?? widget.advocate.sanadUrl);

  String get _documentTitle => widget.isNid
      ? 'জাতীয় পরিচয়পত্র (NID Document)'
      : 'বার কাউন্সিল সনদপত্র (Sanad Document)';

  String get _fileName {
    final url = _signedUrl ?? '';
    final pathOnly = url.split('?').first;
    final parts = pathOnly.split('/');
    return parts.isNotEmpty ? parts.last : 'document.pdf';
  }

  bool get _isImage {
    final lower = _fileName.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
  }

  Future<void> _handleRefresh() async {
    if (widget.onRefreshSignedUrl == null) return;
    setState(() => _isRefreshing = true);
    try {
      await widget.onRefreshSignedUrl!();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _openFullScreenZoom() {
    final url = _signedUrl;
    if (url == null || url.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierColor: AppColors.oxford.withValues(alpha: 0.90),
      builder: (ctx) => _FullScreenDocumentZoomDialog(
        title: _documentTitle,
        fileName: _fileName,
        url: url,
        isImage: _isImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.parchment,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.stone, width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogHeader(context),
              const SizedBox(height: 16),
              _buildSecurityStatusBar(),
              const SizedBox(height: 16),
              _buildPreviewArea(),
              const SizedBox(height: 20),
              _buildDialogActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderIcon(),
        const SizedBox(width: 14),
        Expanded(child: _buildHeaderTitles()),
        _buildHeaderButtons(context),
      ],
    );
  }

  Widget _buildHeaderIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.brassWash,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.verified_user_rounded,
        color: AppColors.brass,
        size: 24,
      ),
    );
  }

  Widget _buildHeaderTitles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_documentTitle, style: AppTypography.displayHeading(fontSize: 18)),
        const SizedBox(height: 2),
        Text(
          widget.advocate.fullName,
          style: AppTypography.banglaBody(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.oxfordSoft,
          ),
        ),
        Text(
          'বার কাউন্সিল নম্বর: ${widget.advocate.barCouncilNo}',
          style: AppTypography.uiBody(
            fontSize: 12,
            color: AppColors.brass,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MinTapTarget(
          minHeight: 40,
          minWidth: 40,
          child: IconButton(
            icon: const Icon(Icons.fullscreen_rounded, color: AppColors.brass),
            tooltip: 'পূর্ণ পর্দা জুম ভিউ (Full-screen Zoom)',
            onPressed: _openFullScreenZoom,
          ),
        ),
        MinTapTarget(
          minHeight: 40,
          minWidth: 40,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.oxford),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.parchmentElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.stone, width: 1.0),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_clock_rounded,
            size: 18,
            color: AppColors.brass,
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildSecurityText()),
          if (widget.onRefreshSignedUrl != null) _buildSecurityRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildSecurityText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'নিরাপদ ১৫-মিনিট মেয়াদী সাইনড ইউআরএল (Signed URL)',
          style: AppTypography.uiBody(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.oxford,
          ),
        ),
        Text(
          widget.advocate.isSignedUrlValid
              ? 'মেয়াদ সক্রিয় (Active — expires in 15m)'
              : 'মেয়াদোত্তীর্ণ বা রিফ্রেশ প্রয়োজন (Expired / Refreshable)',
          style: AppTypography.caption(
            color: widget.advocate.isSignedUrlValid
                ? AppColors.verifiedForest
                : AppColors.burgundy,
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityRefreshButton() {
    return MinTapTarget(
      minHeight: 36,
      minWidth: 36,
      child: TextButton.icon(
        onPressed: _isRefreshing ? null : _handleRefresh,
        icon: _isRefreshing
            ? const BrassArcLoader(size: 14)
            : const Icon(
                Icons.refresh_rounded,
                size: 16,
                color: AppColors.brass,
              ),
        label: Text(
          'রিফ্রেশ',
          style: AppTypography.caption(color: AppColors.brass),
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    return Expanded(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.parchmentSunken,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.stone),
        ),
        clipBehavior: Clip.antiAlias,
        child: _isRefreshing
            ? const Center(
                child: GavelBreathingRingLoader(
                  message: 'নতুন সাইনড ইউআরএল তৈরি হচ্ছে...',
                  size: 60,
                ),
              )
            : _buildPreviewContent(),
      ),
    );
  }

  Widget _buildDialogActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (widget.onReject != null && widget.advocate.status.isPending) ...[
          AppButton.secondary(
            label: 'প্রত্যাখ্যান (Reject)',
            onPressed: () {
              Navigator.of(context).pop();
              widget.onReject!();
            },
          ),
          const SizedBox(width: 12),
        ],
        if (widget.onApprove != null && widget.advocate.status.isPending) ...[
          AppButton.primary(
            label: 'অনুমোদন (Approve)',
            onPressed: () {
              Navigator.of(context).pop();
              widget.onApprove!();
            },
          ),
          const SizedBox(width: 12),
        ],
        AppButton.secondary(
          label: 'বন্ধ করুন (Close)',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildPreviewContent() {
    final url = _signedUrl;
    if (url == null || url.isEmpty) {
      return _buildEmptyPreviewPlaceholder();
    }
    if (_isImage) {
      return _buildInteractiveImageView(url);
    }
    return _buildDocumentFallbackView();
  }

  Widget _buildEmptyPreviewPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.folder_off_rounded,
            size: 48,
            color: AppColors.stoneText,
          ),
          const SizedBox(height: 12),
          Text(
            'কোনো নথি আপলোড করা হয়নি',
            style: AppTypography.banglaBody(
              fontSize: 16,
              color: AppColors.oxfordMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveImageView(String url) {
    return Stack(
      children: [
        InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: GavelBreathingRingLoader(
                    message: 'সনদপত্র লোড হচ্ছে...',
                    size: 64,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return _buildDocumentFallbackView();
              },
            ),
          ),
        ),
        Positioned(bottom: 12, right: 12, child: _buildPinchZoomHint()),
      ],
    );
  }

  Widget _buildPinchZoomHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.oxford.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.zoom_in_rounded,
            color: AppColors.parchment,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            'পিঞ্চ করে জুম করুন (Pinch to zoom)',
            style: AppTypography.caption(color: AppColors.parchment),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentFallbackView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFallbackIcon(),
            const SizedBox(height: 16),
            _buildFallbackLabels(),
            const SizedBox(height: 16),
            _buildFallbackUrl(),
            const SizedBox(height: 12),
            AppButton.ribbon(
              label: 'পূর্ণ পর্দা প্রদর্শন (Open Fullscreen View)',
              icon: const Icon(Icons.fullscreen_rounded, size: 16),
              onPressed: _openFullScreenZoom,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.parchmentElevated,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.brass, width: 1.5),
      ),
      child: const Icon(
        Icons.picture_as_pdf_rounded,
        color: AppColors.burgundy,
        size: 40,
      ),
    );
  }

  Widget _buildFallbackLabels() {
    return Column(
      children: [
        Text(
          'বাংলাদেশ বার কাউন্সিল সনদপত্র কপি',
          style: AppTypography.banglaBody(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.oxford,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          _fileName,
          style: AppTypography.uiBody(
            fontSize: 13,
            color: AppColors.oxfordMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.brassWash,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'আইনজীবী সনদ: ${widget.advocate.barCouncilNo}',
            style: AppTypography.caption(color: AppColors.brass),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackUrl() {
    return Text(
      'নিরাপদ প্রিভিউ লিংক: ${_signedUrl?.split('?').first ?? '—'}',
      style: AppTypography.caption(color: AppColors.stoneText),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}

/// Full-screen dialog providing immersive zoom and pan inspection of verification documents.
class _FullScreenDocumentZoomDialog extends StatefulWidget {
  const _FullScreenDocumentZoomDialog({
    required this.title,
    required this.fileName,
    required this.url,
    required this.isImage,
  });

  final String title;
  final String fileName;
  final String url;
  final bool isImage;

  @override
  State<_FullScreenDocumentZoomDialog> createState() =>
      _FullScreenDocumentZoomDialogState();
}

class _FullScreenDocumentZoomDialogState
    extends State<_FullScreenDocumentZoomDialog> {
  final TransformationController _transformController =
      TransformationController();

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  void _zoomIn() {
    final current = _transformController.value.getMaxScaleOnAxis();
    if (current < 5.0) {
      _transformController.value = Matrix4.copy(_transformController.value)
        ..multiply(Matrix4.diagonal3Values(1.3, 1.3, 1.0));
    }
  }

  void _zoomOut() {
    final current = _transformController.value.getMaxScaleOnAxis();
    if (current > 0.6) {
      _transformController.value = Matrix4.copy(_transformController.value)
        ..multiply(Matrix4.diagonal3Values(0.75, 0.75, 1.0));
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: AppColors.oxford,
      child: SafeArea(
        child: Column(
          children: [
            _buildFullScreenTopBar(context),
            const Divider(color: AppColors.stone, height: 1),
            _buildFullScreenCanvas(),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreenTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.oxford,
      child: Row(
        children: [
          const Icon(Icons.security_rounded, color: AppColors.brass, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: AppTypography.displayHeading(
                    fontSize: 16,
                    color: AppColors.parchment,
                  ),
                ),
                Text(
                  widget.fileName,
                  style: AppTypography.caption(color: AppColors.oxfordMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildZoomControls(context),
        ],
      ),
    );
  }

  Widget _buildZoomControls(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildZoomButton(
          icon: Icons.zoom_out_rounded,
          tooltip: 'জুম কমান',
          onPressed: _zoomOut,
        ),
        _buildZoomButton(
          icon: Icons.zoom_in_rounded,
          tooltip: 'জুম বাড়ান',
          onPressed: _zoomIn,
        ),
        _buildZoomButton(
          icon: Icons.restart_alt_rounded,
          tooltip: 'রিসেট',
          onPressed: _resetZoom,
        ),
        const SizedBox(width: 8),
        _buildZoomButton(
          icon: Icons.close_rounded,
          tooltip: 'বন্ধ করুন',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return MinTapTarget(
      minHeight: 40,
      minWidth: 40,
      child: IconButton(
        icon: Icon(icon, color: AppColors.parchment),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildFullScreenCanvas() {
    return Expanded(
      child: Container(
        color: const Color(0xFF0F1117),
        child: Center(
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.5,
            maxScale: 6.0,
            child: widget.isImage
                ? Image.network(
                    widget.url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: GavelBreathingRingLoader(
                          message: 'পূর্ণ রেজোলিউশন লোড হচ্ছে...',
                          size: 80,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _buildFallbackCard();
                    },
                  )
                : _buildFallbackCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackCard() {
    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stone, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.picture_as_pdf_rounded,
            size: 64,
            color: AppColors.burgundy,
          ),
          const SizedBox(height: 16),
          Text(
            widget.fileName,
            style: AppTypography.displayHeading(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'নিরাপদ ১৫-মিনিট সাইনড প্রিভিউ লিংক',
            style: AppTypography.banglaBody(
              fontSize: 14,
              color: AppColors.oxfordMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.url,
            style: AppTypography.caption(color: AppColors.stoneText),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
