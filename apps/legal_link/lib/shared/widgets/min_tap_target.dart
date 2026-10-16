import 'package:flutter/material.dart';

/// Wraps any interactive widget to ensure it meets the accessibility standard
/// of at least 48x48 dp touch target size (WCAG 2.1 & LegalLink Frontend Rules).
class MinTapTarget extends StatelessWidget {
  const MinTapTarget({
    super.key,
    required this.child,
    this.minWidth = 48.0,
    this.minHeight = 48.0,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final double minWidth;
  final double minHeight;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, minHeight: minHeight),
      child: Align(alignment: alignment, child: child),
    );
  }
}
