import 'package:flutter/material.dart';

import 'neumorphic.dart';
import 'theme.dart';
import 'strings.dart';

/// The Paperwise app icon.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/icon.png',
      width: size,
      height: size,
      cacheWidth: (size * 3).round(),
      excludeFromSemantics: true,
    );
  }
}

/// A round white button with one icon, used for "Back" and similar actions.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: NeuPress(
          radius: 22,
          depth: 5,
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: AppColors.ink)),
        ),
      ),
    );
  }
}

/// Layout shared by every tool screen: header, scrolling body and a bottom bar.
class ToolPage extends StatelessWidget {
  const ToolPage({
    super.key,
    required this.title,
    required this.icon,
    required this.palette,
    required this.body,
    this.bottom,
  });

  final String title;
  final IconData icon;
  final TilePalette palette;
  final Widget body;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final bottom = this.bottom;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 20, 8),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back'.tr,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title.tr,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  NeuBox(
                    pressed: true,
                    radius: 22,
                    depth: 4,
                    child: SizedBox(width: 44, height: 44, child: Icon(icon, color: palette.color, size: 22)),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

/// The big dark pill button at the bottom of tool screens.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = !busy && onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: enabled ? Neu.raised(7) : const <BoxShadow>[],
      ),
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(58),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 17, fontWeight: FontWeight.w700),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: busy
              ? const SizedBox(
                  key: ValueKey('busy'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text(label.tr, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 10),
                    Icon(icon, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A lighter button for second actions like "Share".
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: onPressed == null ? const <BoxShadow>[] : Neu.raised(6),
      ),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label.tr, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.background,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          side: BorderSide.none,
          textStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// A white rounded card.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return NeuBox(radius: 24, depth: 7, padding: padding, child: child);
  }
}

/// A small grey label above a group of options.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.tr,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.muted),
    );
  }
}

/// A row of options where exactly one is picked, like "A4 / Letter / Fit image".
class ChoiceGroup<T> extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final List<T> options;
  final T selected;
  final String Function(T option) labelOf;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < options.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                    child: _Choice(
                      label: labelOf(options[i]),
                      selected: options[i] == selected,
                      onTap: enabled ? () => onChanged(options[i]) : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: NeuBox(
          radius: 14,
          depth: 4,
          pressed: selected,
          child: SizedBox(
            height: 46,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? AppColors.accent : AppColors.ink,
                ),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A friendly message for empty screens, with an optional button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.palette,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final TilePalette palette;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NeuBox(
            pressed: true,
            radius: 24,
            depth: 6,
            child: SizedBox(width: 76, height: 76, child: Icon(icon, size: 36, color: palette.color)),
          ),
          const SizedBox(height: 18),
          Text(
            title.tr,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            message.tr,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.muted),
          ),
          if (action != null) ...[
            const SizedBox(height: 22),
            action,
          ],
        ],
      ),
    );
  }
}

/// A tiny drawing of a page, used as a file thumbnail.
class PageThumb extends StatelessWidget {
  const PageThumb({super.key, this.color, this.lineColor});

  final Color? color;
  final Color? lineColor;

  @override
  Widget build(BuildContext context) {
    Widget line(double widthFactor) => FractionallySizedBox(
          widthFactor: widthFactor,
          alignment: Alignment.centerLeft,
          child: Container(
            height: 3,
            decoration: BoxDecoration(color: lineColor ?? (AppColors.isDark ? const Color(0xFF4A4578) : const Color(0xFFB3AED3)), borderRadius: BorderRadius.circular(2)),
          ),
        );

    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line(1),
        const SizedBox(height: 5),
        line(0.7),
        const SizedBox(height: 5),
        line(1),
        const SizedBox(height: 5),
        line(0.5),
      ],
    );

    final fill = color;
    if (fill != null) {
      return Container(
        width: 44,
        height: 58,
        padding: const EdgeInsets.fromLTRB(7, 9, 7, 9),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(8)),
        child: lines,
      );
    }
    return NeuBox(
      pressed: true,
      radius: 10,
      depth: 3,
      child: SizedBox(
        width: 44,
        height: 58,
        child: Padding(padding: const EdgeInsets.fromLTRB(7, 9, 7, 9), child: lines),
      ),
    );
  }
}

/// Shows a short message at the bottom of the screen.
void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text.tr)));
}
