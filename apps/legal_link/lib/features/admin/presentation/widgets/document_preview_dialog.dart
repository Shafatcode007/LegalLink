import 'package:flutter/material.dart';

import '../../../../shared/shared.dart';
import '../../domain/entities/advocate_verification_item.dart';

/// Modal dialog for reviewing uploaded advocate verification documents via secure temporary signed URLs.
///
/// Features:
/// - Enforces 15-minute signed URL visibility per ADR-011 (no public storage URLs)
/// - Visual expiration badge and refresh capability
/// - Preview rendering with fallback and legal document inspection styling
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
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
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
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _documentTitle,
                          style: AppTypography.displayHeading(fontSize: 18),
                        ),
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
                    ),
                  ),
                  MinTapTarget(
                    minHeight: 40,
                    minWidth: 40,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.oxford,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Security & Signed URL status bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
                    Expanded(
                      child: Column(
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
                      ),
                    ),
                    if (widget.onRefreshSignedUrl != null)
                      MinTapTarget(
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
                            style: AppTypography.caption(
                              color: AppColors.brass,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Document Preview Area
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.parchmentSunken,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.stone),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildPreviewContent(),
                ),
              ),
              const SizedBox(height: 20),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onReject != null &&
                      widget.advocate.status.isPending) ...[
                    AppButton.secondary(
                      label: 'প্রত্যাখ্যান (Reject)',
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onReject!();
                      },
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (widget.onApprove != null &&
                      widget.advocate.status.isPending) ...[
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewContent() {
    final url = _signedUrl;

    if (url == null || url.isEmpty) {
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

    if (_isImage) {
      return InteractiveViewer(
        maxScale: 3.5,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: GavelBreathingRingLoader(message: 'সনদপত্র লোড হচ্ছে...'),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildDocumentFallbackView();
          },
        ),
      );
    }

    return _buildDocumentFallbackView();
  }

  Widget _buildDocumentFallbackView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
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
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            Text(
              'নিরাপদ প্রিভিউ লিংক: ${_signedUrl?.split('?').first ?? '—'}',
              style: AppTypography.caption(color: AppColors.stoneText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
