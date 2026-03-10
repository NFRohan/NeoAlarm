import 'package:alarms_oss/src/features/alarms/application/alarm_list_controller.dart';
import 'package:alarms_oss/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:alarms_oss/src/features/alarms/domain/alarm_spec.dart';
import 'package:alarms_oss/src/features/alarms/presentation/alarm_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(alarmEngineStatusProvider);
      ref.invalidate(alarmListControllerProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alarms = ref.watch(alarmListControllerProvider);
    final engineStatus = ref.watch(alarmEngineStatusProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _createAlarm(context, ref, engineStatus.asData?.value);
        },
        label: const Text('Add alarm'),
        icon: const Icon(Icons.add_alarm),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4EDE1), Color(0xFFE8DDCF), Color(0xFFD8CAB5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Text(
                'alarms-oss',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Exact scheduling, native persistence, and Flutter CRUD now share one vertical slice.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF56483A),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 28),
              _HeroStatusCard(engineStatus: engineStatus.asData?.value),
              const SizedBox(height: 16),
              _EngineStatusBanner(
                status: engineStatus,
                onRequestAccess: () {
                  _requestExactAlarmPermission(context);
                },
              ),
              _NotificationStatusBanner(
                status: engineStatus,
                onRequestAccess: () {
                  _requestNotificationPermission(context);
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Scheduled alarms',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _AlarmListSection(
                alarms: alarms,
                onEdit: (alarm) => _editAlarm(context, ref, alarm),
                onDelete: (alarm) => _deleteAlarm(context, ref, alarm),
                onToggle: (alarm, enabled) =>
                    _setEnabled(context, ref, alarm, enabled),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createAlarm(
    BuildContext context,
    WidgetRef ref,
    AlarmEngineStatus? engineStatus,
  ) async {
    final draft = AlarmSpec.createDraft(
      timezoneId: engineStatus?.timezoneId ?? 'UTC',
    );
    final edited = await AlarmEditorSheet.show(context, alarm: draft);
    if (edited == null || !context.mounted) {
      return;
    }

    await _runRepositoryAction(
      context,
      () => ref.read(alarmListControllerProvider.notifier).saveAlarm(edited),
    );
  }

  Future<void> _editAlarm(
    BuildContext context,
    WidgetRef ref,
    AlarmSpec alarm,
  ) async {
    final edited = await AlarmEditorSheet.show(context, alarm: alarm);
    if (edited == null || !context.mounted) {
      return;
    }

    await _runRepositoryAction(
      context,
      () => ref.read(alarmListControllerProvider.notifier).saveAlarm(edited),
    );
  }

  Future<void> _deleteAlarm(
    BuildContext context,
    WidgetRef ref,
    AlarmSpec alarm,
  ) async {
    await _runRepositoryAction(
      context,
      () =>
          ref.read(alarmListControllerProvider.notifier).deleteAlarm(alarm.id),
    );
  }

  Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    AlarmSpec alarm,
    bool enabled,
  ) async {
    await _runRepositoryAction(
      context,
      () => ref
          .read(alarmListControllerProvider.notifier)
          .setEnabled(id: alarm.id, enabled: enabled),
    );
  }

  Future<void> _runRepositoryAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on PlatformException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? error.code)));
    }
  }

  Future<void> _requestExactAlarmPermission(BuildContext context) async {
    await _runRepositoryAction(
      context,
      () => ref.read(alarmRepositoryProvider).requestExactAlarmPermission(),
    );
  }

  Future<void> _requestNotificationPermission(BuildContext context) async {
    await _runRepositoryAction(
      context,
      () => ref.read(alarmRepositoryProvider).requestNotificationPermission(),
    );
  }
}

class _HeroStatusCard extends StatelessWidget {
  const _HeroStatusCard({required this.engineStatus});

  final AlarmEngineStatus? engineStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: const Color(0xFF1C160F),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Sprint 3 native ring path',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Exact scheduling now hands off to a native ring session with a foreground service.',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              engineStatus == null
                  ? 'Loading device scheduling state...'
                  : 'Device timezone: ${engineStatus!.timezoneId}\n'
                        'Exact alarms: ${engineStatus!.canScheduleExactAlarms ? 'ready' : 'permission required'}\n'
                        'Notifications: ${engineStatus!.notificationsEnabled ? 'ready' : 'permission required'}\n'
                        'Foreground ring service: native Android',
              style: const TextStyle(color: Color(0xFFE8DDCF), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _EngineStatusBanner extends StatelessWidget {
  const _EngineStatusBanner({required this.status, this.onRequestAccess});

  final AsyncValue<AlarmEngineStatus> status;
  final VoidCallback? onRequestAccess;

  @override
  Widget build(BuildContext context) {
    return status.when(
      data: (status) {
        if (status.canScheduleExactAlarms) {
          return const SizedBox.shrink();
        }

        return _InfoBanner(
          title: 'Exact alarm access is not available',
          detail:
              'Enabled alarms need exact-alarm capability. On Android 13+ the app should use the alarm-clock permission automatically; on Android 12L and lower, open the settings handoff below.',
          accent: Color(0xFFC85C3D),
          actionLabel: onRequestAccess == null ? null : 'Open access settings',
          onAction: onRequestAccess,
        );
      },
      loading: () => const _InfoBanner(
        title: 'Checking alarm engine state',
        detail: 'Loading exact-alarm capability and device timezone.',
        accent: Color(0xFF2B6A6C),
      ),
      error: (_, stackTrace) => const _InfoBanner(
        title: 'Alarm engine status could not be loaded',
        detail: 'The native bridge is unavailable or returned an error.',
        accent: Color(0xFFC85C3D),
      ),
    );
  }
}

class _NotificationStatusBanner extends StatelessWidget {
  const _NotificationStatusBanner({required this.status, this.onRequestAccess});

  final AsyncValue<AlarmEngineStatus> status;
  final VoidCallback? onRequestAccess;

  @override
  Widget build(BuildContext context) {
    return status.when(
      data: (status) {
        if (status.notificationsEnabled) {
          return const SizedBox.shrink();
        }

        return _InfoBanner(
          title: 'Notifications are disabled',
          detail:
              'The exact alarm fired, but Android will suppress the Sprint 2 notification path until notification access is granted.',
          accent: const Color(0xFFC85C3D),
          actionLabel: onRequestAccess == null ? null : 'Enable notifications',
          onAction: onRequestAccess,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _AlarmListSection extends StatelessWidget {
  const _AlarmListSection({
    required this.alarms,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final AsyncValue<List<AlarmSpec>> alarms;
  final Future<void> Function(AlarmSpec alarm) onEdit;
  final Future<void> Function(AlarmSpec alarm) onDelete;
  final Future<void> Function(AlarmSpec alarm, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    return alarms.when(
      data: (alarms) {
        if (alarms.isEmpty) {
          return const _InfoBanner(
            title: 'No alarms yet',
            detail:
                'Create a one-time or repeating alarm to exercise the native store and exact scheduling pipeline.',
            accent: Color(0xFF2B6A6C),
          );
        }

        return Column(
          children: [
            for (final alarm in alarms) ...[
              _AlarmCard(
                alarm: alarm,
                onEdit: () => onEdit(alarm),
                onDelete: () => onDelete(alarm),
                onToggle: (enabled) => onToggle(alarm, enabled),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
      loading: () => const _InfoBanner(
        title: 'Loading alarms',
        detail: 'Fetching persisted alarms from the native Android store.',
        accent: Color(0xFF2B6A6C),
      ),
      error: (error, _) => _InfoBanner(
        title: 'Alarm loading failed',
        detail: '$error',
        accent: const Color(0xFFC85C3D),
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({
    required this.alarm,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final AlarmSpec alarm;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;
  final Future<void> Function(bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final nextTrigger = alarm.nextTriggerAtLocal;

    return Card(
      color: const Color(0xFFFFFBF4),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                      Text(
                        localizations.formatTimeOfDay(
                          TimeOfDay(hour: alarm.hour, minute: alarm.minute),
                          alwaysUse24HourFormat:
                              MediaQuery.alwaysUse24HourFormatOf(context),
                        ),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alarm.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alarm.repeatSummary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF56483A),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: alarm.enabled,
                  onChanged: (enabled) {
                    onToggle(enabled);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'Next trigger',
              value: nextTrigger == null
                  ? 'Not scheduled'
                  : '${_weekdayLabel(nextTrigger.weekday)}, ${nextTrigger.month}/${nextTrigger.day} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(nextTrigger), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}',
            ),
            const SizedBox(height: 8),
            _InfoRow(label: 'Timezone', value: alarm.timezoneId),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Snooze policy',
              value:
                  '${alarm.snoozeDurationMinutes} min | ${alarm.maxSnoozes} max',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    onEdit();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    onDelete();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.title,
    required this.detail,
    required this.accent,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String detail;
  final Color accent;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: const Color(0xFFFFFBF4),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                      color: const Color(0xFF56483A),
                      height: 1.45,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF56483A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

String _weekdayLabel(int weekday) {
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
