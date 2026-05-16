import 'package:flutter/material.dart';
import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';

class AlarmTimeBlock extends StatelessWidget {
  const AlarmTimeBlock({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return NeoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.displayMedium?.copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}

class AlarmPeriodChip extends StatelessWidget {
  const AlarmPeriodChip({required this.label, required this.active, super.key});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = active ? NeoColors.primary : NeoColors.panel;

    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: NeoColors.ink, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: NeoColors.foregroundOn(backgroundColor),
        ),
      ),
    );
  }
}

class AlarmEditorSelector extends StatelessWidget {
  const AlarmEditorSelector({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class AlarmEditorToggleRow extends StatelessWidget {
  const AlarmEditorToggleRow({
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return NeoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: NeoColors.subtext),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          NeoToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class AlarmCountChip extends StatelessWidget {
  const AlarmCountChip({
    required this.count,
    required this.selected,
    this.onTap,
    super.key,
  });

  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = selected ? NeoColors.primary : NeoColors.panel;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: NeoColors.ink, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          '$count',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: NeoColors.foregroundOn(backgroundColor),
          ),
        ),
      ),
    );
  }
}

class AlarmEditorWarning extends StatelessWidget {
  const AlarmEditorWarning({
    required this.title,
    required this.detail,
    super.key,
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: NeoColors.warningSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: NeoColors.warningText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: NeoColors.warningText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlarmEditorInfoRow extends StatelessWidget {
  const AlarmEditorInfoRow({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: NeoColors.subtext,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
