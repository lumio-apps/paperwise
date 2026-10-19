import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Shadows for the soft "neumorphic" look: shapes that rise out of the
/// background (raised) or sink into it (pressed).
class Neu {
  Neu._();

  static Color get shadowDark => AppColors.isDark ? const Color(0xFF0F0D20) : const Color(0xFFC6C1E0);
  static Color get shadowLight => AppColors.isDark ? const Color(0xFF2A2650) : const Color(0xFFFFFFFF);

  /// A dark shadow to the bottom right and a light one to the top left.
  static List<BoxShadow> raised(double depth) => [
        BoxShadow(color: shadowDark, offset: Offset(depth, depth), blurRadius: depth * 2),
        BoxShadow(color: shadowLight, offset: Offset(-depth, -depth), blurRadius: depth * 2),
      ];
}

/// Draws the inner shadows of a pressed shape: dark at the top left,
/// light at the bottom right.
class _InsetPainter extends CustomPainter {
  _InsetPainter({required this.radius, required this.depth, required this.dark, required this.light});

  final double radius;
  final double depth;
  final Color dark;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    if (depth <= 0 || size.isEmpty) return;
    final rect = Offset.zero & size;
    final r = math.min(radius, math.min(size.width, size.height) / 2);
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(r));
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(depth * 4))
      ..addRRect(shape);
    final blur = MaskFilter.blur(BlurStyle.normal, depth);
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawPath(outside.shift(Offset(depth, depth)), Paint()..color = dark..maskFilter = blur);
    canvas.drawPath(outside.shift(Offset(-depth, -depth)), Paint()..color = light..maskFilter = blur);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InsetPainter old) =>
      old.radius != radius || old.depth != depth || old.dark != dark || old.light != light;
}

/// A shape in the background color that is either raised or pressed in.
/// Changing [pressed] fades smoothly between the two.
class NeuBox extends StatelessWidget {
  const NeuBox({
    super.key,
    required this.child,
    this.radius = 24,
    this.depth = 8,
    this.pressed = false,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final double depth;
  final bool pressed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 220);
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: Neu.raised(pressed ? 0 : depth),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: duration,
                curve: Curves.easeOutCubic,
                opacity: pressed ? 1 : 0,
                child: CustomPaint(
                  painter: _InsetPainter(
                    radius: radius,
                    depth: depth,
                    dark: Neu.shadowDark,
                    light: Neu.shadowLight,
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// A raised [NeuBox] you can tap. While a finger is down it sinks in and
/// shrinks a little.
class NeuPress extends StatefulWidget {
  const NeuPress({
    super.key,
    required this.child,
    required this.onTap,
    this.radius = 24,
    this.depth = 8,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final double depth;
  final EdgeInsetsGeometry padding;

  @override
  State<NeuPress> createState() => _NeuPressState();
}

class _NeuPressState extends State<NeuPress> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: NeuBox(
            radius: widget.radius,
            depth: widget.depth,
            pressed: _down,
            padding: widget.padding,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Fades and slides its child up when it first appears, after [delay].
/// Does nothing when the phone has animations turned off.
class RiseIn extends StatefulWidget {
  const RiseIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final t = _curve.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
          ),
        );
      },
    );
  }
}
