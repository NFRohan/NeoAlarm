import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_countdown_formatter.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_location_trigger.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_spec.dart';

class AlarmDashboardPage extends StatelessWidget {
  const AlarmDashboardPage({
    required this.alarms,
    required this.engineStatus,
    required this.nextAlarmCountdownText,
    required this.onRequestExactAlarmPermission,
    required this.onRequestNotificationPermission,
    required this.onOpenSettings,
    required this.onEdit,
    required this.onDelete,
    required this.onSkipNext,
    required this.onClearSkippedOccurrence,
    required this.onRepairLocationAlarm,
    required this.onToggle,
    super.key,
  });

  final AsyncValue<List<AlarmSpec>> alarms;
  final AsyncValue<AlarmEngineStatus> engineStatus;
  final String? nextAlarmCountdownText;
  final VoidCallback onRequestExactAlarmPermission;
  final VoidCallback onRequestNotificationPermission;
  final VoidCallback onOpenSettings;
  final Future<void> Function(AlarmSpec alarm) onEdit;
  final Future<void> Function(AlarmSpec alarm) onDelete;
  final Future<void> Function(AlarmSpec alarm) onSkipNext;
  final Future<void> Function(AlarmSpec alarm) onClearSkippedOccurrence;
  final Future<void> Function(AlarmSpec alarm) onRepairLocationAlarm;
  final Future<void> Function(AlarmSpec alarm, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        children: [
          DashboardHeader(
            onOpenSettings: onOpenSettings,
            countdownText: nextAlarmCountdownText,
          ),
          const SizedBox(height: 18),
          PermissionBannerRow(
            engineStatus: engineStatus,
            onRequestExactAlarmPermission: onRequestExactAlarmPermission,
            onRequestNotificationPermission: onRequestNotificationPermission,
          ),
          const SizedBox(height: 22),
          const NeoSectionTitle(title: 'Your alarms'),
          const SizedBox(height: 14),
          AlarmListSection(
            alarms: alarms,
            onEdit: onEdit,
            onDelete: onDelete,
            onSkipNext: onSkipNext,
            onClearSkippedOccurrence: onClearSkippedOccurrence,
            onRepairLocationAlarm: onRepairLocationAlarm,
            onToggle: onToggle,
          ),
        ],
      ),
    );
  }
}

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.onOpenSettings,
    required this.countdownText,
    super.key,
  });

  final VoidCallback onOpenSettings;
  final String? countdownText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NeoAlarm',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                countdownText ?? 'Exact alarms. No ads. No cloud.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: NeoColors.subtext,
                ),
              ),
            ],
          ),
        ),
        NeoSquareIconButton(
          icon: Icons.settings,
          backgroundColor: NeoColors.cyan,
          foregroundColor: NeoColors.accentInk,
          size: 52,
          onPressed: onOpenSettings,
        ),
      ],
    );
  }
}

class PermissionBannerRow extends StatelessWidget {
  const PermissionBannerRow({
    required this.engineStatus,
    required this.onRequestExactAlarmPermission,
    required this.onRequestNotificationPermission,
    super.key,
  });

  final AsyncValue<AlarmEngineStatus> engineStatus;
  final VoidCallback onRequestExactAlarmPermission;
  final VoidCallback onRequestNotificationPermission;

  @override
  Widget build(BuildContext context) {
    return engineStatus.when(
      data: (status) {
        if (status.canScheduleExactAlarms && status.notificationsEnabled) {
          return const SizedBox.shrink();
        }

        final needsExact = !status.canScheduleExactAlarms;
        return NeoPanel(
          color: NeoColors.orange,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.notifications_active, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      needsExact
                          ? 'Enable exact alarms'
                          : 'Enable notifications',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      needsExact
                          ? 'Precise wake-up timing is blocked until Android grants exact-alarm access.'
                          : 'Notification affordances are suppressed until notification access is granted.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              NeoActionButton(
                label: needsExact ? 'Fix' : 'Enable',
                backgroundColor: NeoColors.panel,
                compact: true,
                onPressed: needsExact
                    ? onRequestExactAlarmPermission
                    : onRequestNotificationPermission,
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class AlarmListSection extends StatelessWidget {
  const AlarmListSection({
    required this.alarms,
    required this.onEdit,
    required this.onDelete,
    required this.onSkipNext,
    required this.onClearSkippedOccurrence,
    required this.onRepairLocationAlarm,
    required this.onToggle,
    super.key,
  });

  final AsyncValue<List<AlarmSpec>> alarms;
  final Future<void> Function(AlarmSpec alarm) onEdit;
  final Future<void> Function(AlarmSpec alarm) onDelete;
  final Future<void> Function(AlarmSpec alarm) onSkipNext;
  final Future<void> Function(AlarmSpec alarm) onClearSkippedOccurrence;
  final Future<void> Function(AlarmSpec alarm) onRepairLocationAlarm;
  final Future<void> Function(AlarmSpec alarm, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    return alarms.when(
      data: (alarms) {
        if (alarms.isEmpty) {
          return NeoPanel(
            color: NeoColors.panel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NO ALARMS YET',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Setup is done. Create your first one-time or repeating alarm and NeoAlarm will handle the rest.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: NeoColors.subtext),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (final alarm in alarms) ...[
              AlarmCard(
                alarm: alarm,
                onEdit: () => onEdit(alarm),
                onDelete: () => onDelete(alarm),
                onSkipNext: () => onSkipNext(alarm),
                onClearSkippedOccurrence: () => onClearSkippedOccurrence(alarm),
                onRepairLocationAlarm: () => onRepairLocationAlarm(alarm),
                onToggle: (enabled) => onToggle(alarm, enabled),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
      loading: () => const InfoBanner(
        title: 'Loading alarms',
        detail: 'Fetching persisted alarms from the native Android store.',
        accent: Color(0xFF2B6A6C),
      ),
      error: (error, _) => InfoBanner(
        title: 'Alarm loading failed',
        detail: '$error',
        accent: const Color(0xFFC85C3D),
      ),
    );
  }
}

class AlarmCard extends StatefulWidget {
  const AlarmCard({
    required this.alarm,
    required this.onEdit,
    required this.onDelete,
    required this.onSkipNext,
    required this.onClearSkippedOccurrence,
    required this.onRepairLocationAlarm,
    required this.onToggle,
    super.key,
  });

  final AlarmSpec alarm;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;
  final Future<void> Function() onSkipNext;
  final Future<void> Function() onClearSkippedOccurrence;
  final Future<void> Function() onRepairLocationAlarm;
  final Future<void> Function(bool enabled) onToggle;

  @override
  State<AlarmCard> createState() => _AlarmCardState();
}

class _AlarmCardState extends State<AlarmCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final alarm = widget.alarm;
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final nextTrigger = alarm.nextTriggerAtLocal;
    final locationTrigger = alarm.locationTrigger;
    final collapsedSummary = _collapsedSummary(
      context,
      alarm,
      nextTrigger,
      localizations,
    );
    final collapsedWarning = _collapsedWarning(alarm, locationTrigger);
    final displayLabel = _displayLabel(alarm, locationTrigger);
    final repairActionLabel = locationTrigger?.repairActionLabel;

    return Opacity(
      opacity: alarm.enabled ? 1 : 0.78,
      child: NeoPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (displayLabel != null) ...[
                        Text(
                          displayLabel.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: NeoColors.subtext,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (alarm.isLocationAlarm)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LOCATION',
                              style: theme.textTheme.displayMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              locationTrigger?.label ?? 'Destination',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: NeoColors.subtext,
                              ),
                            ),
                          ],
                        )
                      else
                        RichText(
                          text: TextSpan(
                            style: theme.textTheme.displayMedium,
                            children: [
                              TextSpan(
                                text: localizations
                                    .formatTimeOfDay(
                                      TimeOfDay(
                                        hour: alarm.hour,
                                        minute: alarm.minute,
                                      ),
                                      alwaysUse24HourFormat:
                                          MediaQuery.alwaysUse24HourFormatOf(
                                            context,
                                          ),
                                    )
                                    .replaceAll(RegExp(r'\s?[AP]M$'), ''),
                              ),
                              TextSpan(
                                text:
                                    MediaQuery.alwaysUse24HourFormatOf(context)
                                    ? ''
                                    : ' ${localizations.formatTimeOfDay(TimeOfDay(hour: alarm.hour, minute: alarm.minute), alwaysUse24HourFormat: false).split(' ').last}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        collapsedSummary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: NeoColors.subtext,
                        ),
                      ),
                      if (collapsedWarning != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          collapsedWarning,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: NeoColors.warningText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _expanded = !_expanded;
                        });
                      },
                      child: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    NeoToggle(
                      value: alarm.enabled,
                      onChanged: (enabled) {
                        widget.onToggle(enabled);
                      },
                    ),
                  ],
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (alarm.isTimeAlarm) ...[
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: AlarmWeekday.values
                            .map(
                              (weekday) => NeoDayChip(
                                label: weekday.shortLabel.characters.first,
                                selected: alarm.weekdays.contains(weekday),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 16),
                      InfoRow(
                        label: 'Next',
                        value: nextTrigger == null
                            ? 'Not scheduled'
                            : '${weekdayLabel(nextTrigger.weekday)}, ${nextTrigger.month}/${nextTrigger.day} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(nextTrigger), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}',
                      ),
                    ] else ...[
                      InfoRow(
                        label: 'Trigger',
                        value:
                            locationTrigger?.radiusSummary ?? 'Not configured',
                      ),
                      const SizedBox(height: 8),
                      InfoRow(
                        label: 'Status',
                        value: locationTrigger?.health.label ?? 'Not evaluated',
                        warning: alarm.hasLocationWarning,
                      ),
                    ],
                    if (alarm.usesSpecificTimezone) ...[
                      const SizedBox(height: 8),
                      InfoRow(label: 'Time zone', value: alarm.timezoneSummary),
                    ],
                    if (alarm.isLocationAlarm && repairActionLabel != null) ...[
                      const SizedBox(height: 12),
                      NeoActionButton(
                        label: repairActionLabel,
                        backgroundColor: NeoColors.cyan,
                        foregroundColor: NeoColors.accentInk,
                        onPressed: widget.onRepairLocationAlarm,
                        expand: true,
                      ),
                    ],
                    const SizedBox(height: 8),
                    InfoRow(
                      label: 'Snooze',
                      value:
                          '${alarm.snoozeDurationMinutes} ${alarm.snoozeDurationMinutes == 1 ? 'minute' : 'minutes'} | ${alarm.maxSnoozes} max',
                    ),
                    const SizedBox(height: 8),
                    InfoRow(label: 'Tone', value: alarm.ringtoneSummary),
                    if (alarm.hasCustomToneWarning) ...[
                      const SizedBox(height: 8),
                      const InfoRow(
                        label: 'Tone status',
                        value:
                            'Fallback tone active until custom tone is repaired',
                        warning: true,
                      ),
                    ],
                    const SizedBox(height: 8),
                    InfoRow(label: 'Volume', value: alarm.volumeSummary),
                    if (alarm.hasPendingSkippedOccurrence) ...[
                      const SizedBox(height: 8),
                      InfoRow(
                        label: 'Skip next',
                        value: formatSkippedOccurrenceLabel(
                          alarm.skippedOccurrenceLocalDate!,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    InfoRow(label: 'Dismiss', value: alarm.missionSummary),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        NeoSquareIconButton(
                          icon: Icons.edit,
                          size: 42,
                          backgroundColor: NeoColors.panel,
                          onPressed: () {
                            widget.onEdit();
                          },
                        ),
                        const SizedBox(width: 10),
                        NeoSquareIconButton(
                          icon: Icons.delete,
                          size: 42,
                          backgroundColor: NeoColors.warm,
                          foregroundColor: Colors.red.shade700,
                          onPressed: () {
                            widget.onDelete();
                          },
                        ),
                        if (alarm.repeats) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: NeoActionButton(
                              label: alarm.hasPendingSkippedOccurrence
                                  ? 'Undo skip'
                                  : 'Skip next',
                              compact: true,
                              backgroundColor: alarm.hasPendingSkippedOccurrence
                                  ? NeoColors.warm
                                  : NeoColors.panel,
                              onPressed: alarm.enabled
                                  ? () {
                                      if (alarm.hasPendingSkippedOccurrence) {
                                        widget.onClearSkippedOccurrence();
                                      } else {
                                        widget.onSkipNext();
                                      }
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
              sizeCurve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }

  String? _displayLabel(
    AlarmSpec alarm,
    AlarmLocationTrigger? locationTrigger,
  ) {
    final normalized = alarm.label.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.toLowerCase() == 'alarm') {
      return null;
    }
    if (alarm.isLocationAlarm &&
        locationTrigger != null &&
        normalized == locationTrigger.label.trim()) {
      return null;
    }
    return normalized;
  }

  String _collapsedSummary(
    BuildContext context,
    AlarmSpec alarm,
    DateTime? nextTrigger,
    MaterialLocalizations localizations,
  ) {
    if (alarm.isLocationAlarm) {
      final locationTrigger = alarm.locationTrigger;
      final radius = locationTrigger?.radiusSummary ?? 'Not configured';
      final status = locationTrigger?.health.label ?? 'Not evaluated';
      return '$radius | $status';
    }

    final repeat = alarm.repeatSummary;
    final next = nextTrigger == null
        ? 'Not scheduled'
        : '${weekdayLabel(nextTrigger.weekday)}, ${nextTrigger.month}/${nextTrigger.day} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(nextTrigger), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
    return '$repeat | $next';
  }

  String? _collapsedWarning(
    AlarmSpec alarm,
    AlarmLocationTrigger? locationTrigger,
  ) {
    if (alarm.hasCustomToneWarning) {
      return 'Fallback tone active until custom tone is repaired.';
    }
    if (alarm.hasLocationWarning) {
      return locationTrigger?.health.label ?? 'Location alarm needs attention.';
    }
    if (alarm.hasPendingSkippedOccurrence) {
      return 'Skip next: ${formatSkippedOccurrenceLabel(alarm.skippedOccurrenceLocalDate!)}';
    }
    if (alarm.usesSpecificTimezone) {
      return alarm.timezoneSummary;
    }
    return null;
  }
}

String formatSkippedOccurrenceLabel(String localDate) {
  final parsed = DateTime.tryParse(localDate);
  if (parsed == null) {
    return localDate;
  }

  return '${weekdayLabel(parsed.weekday)}, ${parsed.month}/${parsed.day}';
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    required this.title,
    required this.detail,
    required this.accent,
    super.key,
  });

  final String title;
  final String detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NeoPanel(
      color: NeoColors.warm,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NeoColors.warningText,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    required this.label,
    required this.value,
    this.warning = false,
    super.key,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: warning ? NeoColors.warningText : NeoColors.subtext,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: warning ? NeoColors.warningText : null,
            ),
          ),
        ),
      ],
    );
  }
}

String weekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'Mon',
    DateTime.tuesday => 'Tue',
    DateTime.wednesday => 'Wed',
    DateTime.thursday => 'Thu',
    DateTime.friday => 'Fri',
    DateTime.saturday => 'Sat',
    DateTime.sunday => 'Sun',
    _ => '',
  };
}

String? nextAlarmCountdownText(List<AlarmSpec> alarms) {
  final soonestAlarm = alarms
      .where((alarm) => alarm.enabled && alarm.nextTriggerAtLocal != null)
      .fold<AlarmSpec?>(null, (currentSoonest, alarm) {
        if (currentSoonest == null) {
          return alarm;
        }

        final currentTrigger = currentSoonest.nextTriggerAtLocal!;
        final nextTrigger = alarm.nextTriggerAtLocal!;
        return nextTrigger.isBefore(currentTrigger) ? alarm : currentSoonest;
      });

  if (soonestAlarm == null) {
    return null;
  }

  return 'Next alarm in ${formatAlarmCountdown(soonestAlarm.nextTriggerAtLocal!)}'
      .replaceFirst('Alarm in ', '');
}
