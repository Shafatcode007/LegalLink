import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:legal_link/shared/shared.dart';

import '../../../../l10n/app_localizations.dart';

class HoldToConfirmSosButton extends StatefulWidget {
  const HoldToConfirmSosButton({
    required this.onConfirmed,
    this.compact = false,
    this.confirmationBody,
    super.key,
  });
  static const holdDuration = Duration(milliseconds: 600);
  final VoidCallback onConfirmed;
  final bool compact;
  final String? confirmationBody;
  @override
  State<HoldToConfirmSosButton> createState() => _HoldState();
}

class _HoldState extends State<HoldToConfirmSosButton>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _focus = FocusNode();
  late final AnimationController _hold, _pulse;
  Timer? _timer;
  int? _pointer;
  LogicalKeyboardKey? _key;
  bool _focused = false, _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hold = AnimationController(
      vsync: this,
      duration: HoldToConfirmSosButton.holdDuration,
      animationBehavior: AnimationBehavior.preserve,
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer(HoldToConfirmSosButton.holdDuration, () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      widget.onConfirmed();
    });
    _hold.forward(from: 0);
  }

  void _cancel() {
    _timer?.cancel();
    _pointer = null;
    _key = null;
    _hold.reset();
  }

  Future<void> _accessibleConfirm() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sosConfirmTitle),
        content: Text(widget.confirmationBody ?? l10n.sosConfirmBody),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.sosStart),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (result == true && mounted) widget.onConfirmed();
  }

  KeyEventResult _keyboard(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.space && key != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent && _key == null && _pointer == null) {
      _key = key;
      _start();
    } else if (event is KeyUpEvent && _key == key) {
      _cancel();
    }
    return KeyEventResult.handled;
  }

  void _down(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton || _pointer != null || _key != null) {
      return;
    }
    _focus.requestFocus();
    _pointer = event.pointer;
    _start();
  }

  void _move(PointerMoveEvent event, double diameter) {
    if (event.pointer != _pointer) return;
    final center = Offset((diameter + 32) / 2, (diameter + 32) / 2);
    if ((event.localPosition - center).distance > diameter / 2 + 16) _cancel();
  }

  double _diameter(BuildContext context) {
    if (widget.compact) return 80;
    return MediaQuery.sizeOf(context).width < 360 &&
            MediaQuery.textScalerOf(context).scale(1) < 1.3
        ? 148
        : 200;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final diameter = _diameter(context);
    return Semantics(
      button: true,
      label: l10n.sosTitle,
      hint: l10n.sosAccessibilityHint,
      onTap: _accessibleConfirm,
      excludeSemantics: true,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _keyboard,
        onFocusChange: (focused) {
          setState(() => _focused = focused);
          if (!focused) _cancel();
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Listener(
            onPointerDown: _down,
            onPointerUp: (event) {
              if (event.pointer == _pointer) _cancel();
            },
            onPointerCancel: (event) {
              if (event.pointer == _pointer) _cancel();
            },
            onPointerMove: (event) => _move(event, diameter),
            child: _ring(diameter, l10n),
          ),
        ),
      ),
    );
  }

  Widget _ring(double diameter, AppLocalizations l10n) => AnimatedBuilder(
    animation: Listenable.merge([_hold, _pulse]),
    builder: (context, child) => SizedBox.square(
      dimension: diameter + 32,
      child: CustomPaint(
        painter: _SosRingPainter(
          progress: _hold.value,
          pulse: _pulse.value,
          focused: _focused,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [AppColors.burgundy, AppColors.burgundyHover],
              ),
            ),
            child: _content(diameter, l10n),
          ),
        ),
      ),
    ),
  );

  Widget _content(double diameter, AppLocalizations l10n) => Center(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sos_rounded,
            size: widget.compact
                ? 16
                : diameter < 200
                ? 32
                : 48,
            color: AppColors.white,
          ),
          Flexible(
            child: Text(
              widget.compact ? l10n.sosShortLabel : l10n.sosButtonLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.white,
                fontSize: widget.compact ? 16 : 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _hold.dispose();
    _pulse.dispose();
    _focus.dispose();
    super.dispose();
  }
}

class _SosRingPainter extends CustomPainter {
  const _SosRingPainter({
    required this.progress,
    required this.pulse,
    required this.focused,
  });
  final double progress;
  final double pulse;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 10;
    canvas.drawCircle(
      center,
      radius + pulse * 3,
      Paint()
        ..color = AppColors.burgundy.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );
    final paint = Paint()
      ..color = AppColors.brass
      ..style = PaintingStyle.stroke
      ..strokeWidth = focused ? 4 : 3;
    if (focused) canvas.drawCircle(center, radius + 8, paint);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SosRingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      pulse != oldDelegate.pulse ||
      focused != oldDelegate.focused;
}
