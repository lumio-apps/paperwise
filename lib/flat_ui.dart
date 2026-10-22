import 'package:flutter/material.dart';

import 'theme.dart';

/// A flat panel: a card color with a thin outline. It draws no shadows, so it
/// stays cheap to paint even in long lists. A [pressed] panel (a chosen option,
/// an icon well) is filled with a slightly different color instead.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.radius = 20,
    this.pressed = false,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final bool pressed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: pressed ? AppColors.track : AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: pressed ? Colors.transparent : AppColors.line),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A [Panel] you can tap. While a finger is down it takes the pressed color.
class PanelPress extends StatefulWidget {
  const PanelPress({
    super.key,
    required this.child,
    required this.onTap,
    this.radius = 20,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  State<PanelPress> createState() => _PanelPressState();
}

class _PanelPressState extends State<PanelPress> {
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
        child: Panel(
          radius: widget.radius,
          pressed: _down,
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}
