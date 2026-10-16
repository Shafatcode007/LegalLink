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
