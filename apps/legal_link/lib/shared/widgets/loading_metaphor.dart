import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';

/// Loading Metaphor implementation for Ain Sohay / LegalLink.
/// Rule: NEVER use generic circular progress spinners.
/// Uses a breathing brass ring around a gavel or skeleton loaders.
class GavelBreathingRingLoader extends StatefulWidget {
  const GavelBreathingRingLoader({super.key, this.message, this.size = 72.0});

  /// Optional message beneath the loading metaphor (e.g. 'যাচাই করা হচ্ছে...')
  final String? message;
  final double size;

  @override
  State<GavelBreathingRingLoader> createState() =>
      _GavelBreathingRingLoaderState();
}

class _GavelBreathingRingLoaderState extends State<GavelBreathingRingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return SizedBox(
              width: widget.size * 1.5,
              height: widget.size * 1.5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer breathing brass wash aura
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: widget.size * 1.35,
                      height: widget.size * 1.35,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brassWash.withValues(
                          alpha: 0.4 + (_pulseAnimation.value * 0.4),
                        ),
                      ),
                    ),
                  ),
                  // Middle brass ring
                  Container(
                    width: widget.size * 1.1,
                    height: widget.size * 1.1,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.brass.withValues(
                          alpha: 0.6 + (_pulseAnimation.value * 0.4),
                        ),
                        width: 2.5,
                      ),
                    ),
                  ),
                  // Inner gavel icon
                  Container(
                    width: widget.size * 0.8,
                    height: widget.size * 0.8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.parchmentElevated,
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: AppColors.brass,
                      size: 28,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.message!,
            style: AppTypography.banglaBody(
              fontSize: 16,
              color: AppColors.oxfordSoft,
            ),
          ),
        ],
      ],
    );
  }
}

/// Shimmer skeleton loader for text lines and card placeholders
class LegalSkeletonLoader extends StatefulWidget {
  const LegalSkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 16.0,
    this.borderRadius = 4.0,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<LegalSkeletonLoader> createState() => _LegalSkeletonLoaderState();
}

class _LegalSkeletonLoaderState extends State<LegalSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                AppColors.parchmentSunken,
                Color.lerp(
                  AppColors.parchmentSunken,
                  AppColors.parchmentElevated,
                  _controller.value,
                )!,
                AppColors.parchmentSunken,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Rotating arc loading metaphor per ui_ux.md §4.2 (Button submit & sync).
/// Replaces generic circular progress spinners everywhere in the app.
class BrassArcLoader extends StatefulWidget {
  const BrassArcLoader({
    super.key,
    this.size = 18.0,
    this.strokeWidth = 2.0,
    this.color = AppColors.brass,
  });

  final double size;
  final double strokeWidth;
  final Color color;

  @override
  State<BrassArcLoader> createState() => _BrassArcLoaderState();
}

class _BrassArcLoaderState extends State<BrassArcLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * 3.141592653589793,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _ArcPainter(
              color: widget.color,
              strokeWidth: widget.strokeWidth,
            ),
          ),
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    canvas.drawArc(rect, 0, 4.71238898038, false, paint); // 270 degrees
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
