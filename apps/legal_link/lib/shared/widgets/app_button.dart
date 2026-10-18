import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import 'min_tap_target.dart';

enum ButtonVariant { primary, secondary, ribbon, sos }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : variant = ButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : variant = ButtonVariant.secondary;

  const AppButton.ribbon({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : variant = ButtonVariant.ribbon;

  const AppButton.sos({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
  }) : variant = ButtonVariant.sos;

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isHovered = false;

  bool get _isEnabled {
    return widget.onPressed != null && !widget.isLoading;
  }

  Color _getBackgroundColor() {
    if (widget.isLoading) {
      switch (widget.variant) {
        case ButtonVariant.primary:
          return AppColors.brass;
        case ButtonVariant.secondary:
          return AppColors.parchment;
        case ButtonVariant.ribbon:
          return Colors.transparent;
        case ButtonVariant.sos:
          return AppColors.burgundy;
      }
    }

    if (!_isEnabled) {
      return AppColors.parchmentSunken;
    }

    switch (widget.variant) {
      case ButtonVariant.primary:
        return _isHovered ? AppColors.brassHover : AppColors.brass;

      case ButtonVariant.secondary:
        return _isHovered ? AppColors.parchmentElevated : AppColors.parchment;

      case ButtonVariant.ribbon:
        return _isHovered ? AppColors.brassWash : Colors.transparent;

      case ButtonVariant.sos:
        return _isHovered ? AppColors.burgundyHover : AppColors.burgundy;
    }
  }

  Color _getTextColor() {
    if (widget.isLoading) {
      switch (widget.variant) {
        case ButtonVariant.primary:
        case ButtonVariant.sos:
          return AppColors.parchment;

        case ButtonVariant.secondary:
        case ButtonVariant.ribbon:
          return AppColors.brass;
      }
    }

    if (!_isEnabled) {
      return AppColors.stoneText;
    }

    switch (widget.variant) {
      case ButtonVariant.primary:
      case ButtonVariant.sos:
        return AppColors.parchment;

      case ButtonVariant.secondary:
        return AppColors.oxford;

      case ButtonVariant.ribbon:
        return AppColors.brass;
    }
  }

  Border? _getBorder() {
    if (widget.variant == ButtonVariant.secondary) {
      return Border.all(color: AppColors.stone, width: 1.5);
    }

    if (widget.variant == ButtonVariant.ribbon) {
      return Border(
        bottom: BorderSide(
          color: _isHovered ? AppColors.brass : AppColors.stone,
          width: 1.5,
        ),
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final minHeight = widget.variant == ButtonVariant.sos ? 56.0 : 48.0;

    final textColor = _getTextColor();

    final content = IconTheme(
      data: IconThemeData(color: textColor, size: 20),
      child: Row(
        mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.isLoading)
            _ButtonArcLoader(color: textColor)
          else ...[
            if (widget.icon != null) ...[
              widget.icon!,
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: textColor,
                  fontSize: widget.variant == ButtonVariant.sos ? 17 : 15,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ],
      ),
    );

    return MinTapTarget(
      minHeight: minHeight,
      minWidth: widget.isFullWidth ? double.infinity : 48,
      child: MouseRegion(
        onEnter: (_) {
          setState(() {
            _isHovered = true;
          });
        },
        onExit: (_) {
          setState(() {
            _isHovered = false;
          });
        },
        child: SizedBox(
          width: widget.isFullWidth ? double.infinity : null,
          height: minHeight,
          child: Material(
            color: _getBackgroundColor(),
            borderRadius: widget.variant == ButtonVariant.ribbon
                ? BorderRadius.zero
                : BorderRadius.circular(8),
            child: InkWell(
              onTap: _isEnabled ? widget.onPressed : null,
              borderRadius: widget.variant == ButtonVariant.ribbon
                  ? BorderRadius.zero
                  : BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  border: _getBorder(),
                  borderRadius: widget.variant == ButtonVariant.ribbon
                      ? BorderRadius.zero
                      : BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonArcLoader extends StatefulWidget {
  const _ButtonArcLoader({required this.color});

  final Color color;

  @override
  State<_ButtonArcLoader> createState() => _ButtonArcLoaderState();
}

class _ButtonArcLoaderState extends State<_ButtonArcLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: const Size.square(20),
        painter: _ButtonArcPainter(color: widget.color),
      ),
    );
  }
}

class _ButtonArcPainter extends CustomPainter {
  const _ButtonArcPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);

    canvas.drawArc(rect, -math.pi / 2, math.pi * 1.35, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ButtonArcPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
