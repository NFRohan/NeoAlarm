import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class NeoPanel extends StatelessWidget {
  const NeoPanel({
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.borderWidth = 3,
    this.shadowOffset = const Offset(4, 4),
    super.key,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double borderWidth;
  final Offset shadowOffset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: neoPanelDecoration(
        color: color ?? NeoColors.panel,
        borderWidth: borderWidth,
        shadowOffset: shadowOffset,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class NeoActionButton extends StatelessWidget {
  const NeoActionButton({
    required this.label,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.compact = false,
    this.expand = false,
    this.suppressSplash = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry padding;
  final bool compact;
  final bool expand;
  final bool suppressSplash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedBackground = onPressed == null
        ? NeoColors.disabled
        : (backgroundColor ?? NeoColors.primary);
    final baseForeground =
        foregroundColor ?? NeoColors.foregroundOn(resolvedBackground);
    final resolvedForeground = onPressed == null
        ? baseForeground.withValues(alpha: 0.7)
        : baseForeground;
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        splashFactory: suppressSplash ? NoSplash.splashFactory : null,
        highlightColor: suppressSplash ? Colors.transparent : null,
        splashColor: suppressSplash ? Colors.transparent : null,
        hoverColor: suppressSplash ? Colors.transparent : null,
        child: Container(
          decoration: BoxDecoration(
            color: resolvedBackground,
            border: Border.all(color: NeoColors.ink, width: compact ? 2 : 3),
            boxShadow: neoShadow(
              offset: compact ? const Offset(2, 2) : const Offset(4, 4),
            ),
          ),
          padding: padding,
          alignment: Alignment.center,
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: resolvedForeground,
              fontSize: compact ? 11 : 14,
              letterSpacing: compact ? 0.4 : 0.8,
            ),
          ),
        ),
      ),
    );

    if (!expand) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}

class NeoSquareIconButton extends StatelessWidget {
  const NeoSquareIconButton({
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.size = 44,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolvedBackground = onPressed == null
        ? NeoColors.disabled
        : (backgroundColor ?? NeoColors.panel);
    final baseForeground =
        foregroundColor ?? NeoColors.foregroundOn(resolvedBackground);
    final resolvedForeground = onPressed == null
        ? baseForeground.withValues(alpha: 0.65)
        : baseForeground;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: resolvedBackground,
            border: Border.all(color: NeoColors.ink, width: 3),
            boxShadow: neoShadow(offset: const Offset(3, 3)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: resolvedForeground, size: size * 0.48),
        ),
      ),
    );
  }
}

class NeoPill extends StatelessWidget {
  const NeoPill({
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    super.key,
  });

  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedBackground = backgroundColor ?? NeoColors.warm;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: resolvedBackground,
        border: Border.all(color: NeoColors.ink, width: 2),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: foregroundColor ?? NeoColors.foregroundOn(resolvedBackground),
        ),
      ),
    );
  }
}

class NeoToggle extends StatelessWidget {
  const NeoToggle({
    required this.value,
    this.onChanged,
    this.activeTrackColor,
    this.inactiveTrackColor,
    this.activeThumbColor,
    this.inactiveThumbColor,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeTrackColor;
  final Color? inactiveTrackColor;
  final Color? activeThumbColor;
  final Color? inactiveThumbColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: SizedBox(
        width: 60,
        height: 34,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: value
                ? (activeTrackColor ?? NeoColors.success)
                : (inactiveTrackColor ?? NeoColors.disabled),
            border: Border.all(color: NeoColors.ink, width: 3),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 30,
              height: 34,
              decoration: BoxDecoration(
                color: value
                    ? (activeThumbColor ?? NeoColors.primary)
                    : (inactiveThumbColor ?? NeoColors.panel),
                border: Border.all(color: NeoColors.ink, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NeoDayChip extends StatelessWidget {
  const NeoDayChip({
    required this.label,
    required this.selected,
    this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = selected ? NeoColors.primary : NeoColors.panel;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: NeoColors.ink, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: NeoColors.foregroundOn(backgroundColor),
          ),
        ),
      ),
    );
  }
}

class NeoSectionTitle extends StatelessWidget {
  const NeoSectionTitle({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: theme.textTheme.headlineLarge),
        Container(
          width: 132,
          height: 6,
          margin: const EdgeInsets.only(top: 4),
          color: NeoColors.primary,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: NeoColors.subtext,
            ),
          ),
        ],
      ],
    );
  }
}
