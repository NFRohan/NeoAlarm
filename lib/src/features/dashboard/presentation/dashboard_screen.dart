import 'dart:async';

import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:neoalarm/src/features/alarms/application/alarm_list_controller.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_countdown_formatter.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_spec.dart';
import 'package:neoalarm/src/features/alarms/presentation/alarm_editor_sheet.dart';
import 'package:neoalarm/src/features/onboarding/application/onboarding_controller.dart';
import 'package:neoalarm/src/features/settings/application/theme_mode_controller.dart';
import 'package:neoalarm/src/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _DashboardTab { alarms, settings }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  _DashboardTab _selectedTab = _DashboardTab.alarms;
  Timer? _countdownTicker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _countdownTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(alarmEngineStatusProvider);
      if (_selectedTab == _DashboardTab.alarms) {
        ref.invalidate(alarmListControllerProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alarms = ref.watch(alarmListControllerProvider);
    final engineStatus = ref.watch(alarmEngineStatusProvider);
    final themeMode = ref.watch(appThemeModeControllerProvider);
    final showAddAlarm = _selectedTab == _DashboardTab.alarms;

    return PopScope<Object?>(
      canPop: _selectedTab == _DashboardTab.alarms,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedTab == _DashboardTab.settings) {
          setState(() {
            _selectedTab = _DashboardTab.alarms;
          });
        }
      },
      child: Scaffold(
        backgroundColor: NeoColors.paper,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: showAddAlarm
            ? Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NeoSquareIconButton(
                  icon: Icons.add,
                  backgroundColor: NeoColors.primary,
                  foregroundColor: NeoColors.accentInk,
                  size: 76,
                  onPressed: () {
                    _createAlarm(context, ref, engineStatus.asData?.value);
                  },
                ),
              )
            : null,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _selectedTab == _DashboardTab.alarms
              ? _AlarmDashboardPage(
                  key: const ValueKey('alarms-tab'),
                  alarms: alarms,
                  engineStatus: engineStatus,
                  nextAlarmCountdownText: _nextAlarmCountdownText(
                    alarms.asData?.value ?? const [],
                  ),
                  onRequestExactAlarmPermission: () {
                    _requestExactAlarmPermission(context);
                  },
                  onRequestNotificationPermission: () {
                    _requestNotificationPermission(context);
                  },
                  onOpenSettings: () {
                    setState(() {
                      _selectedTab = _DashboardTab.settings;
                    });
                  },
                  onEdit: (alarm) => _editAlarm(
                    context,
                    ref,
                    alarm,
                    engineStatus.asData?.value,
                  ),
                  onDelete: (alarm) => _deleteAlarm(context, ref, alarm),
                  onToggle: (alarm, enabled) =>
                      _setEnabled(context, ref, alarm, enabled),
                )
              : SettingsScreen(
                  key: const ValueKey('settings-tab'),
                  status: engineStatus,
                  themeMode: themeMode,
                  onBack: () {
                    setState(() {
                      _selectedTab = _DashboardTab.alarms;
                    });
                  },
                  onSetDarkModeEnabled: (enabled) => ref
                      .read(appThemeModeControllerProvider.notifier)
                      .setDarkModeEnabled(enabled),
                  onRequestExactAlarmAccess: () {
                    _requestExactAlarmPermission(context);
                  },
                  onRequestNotificationAccess: () {
                    _requestNotificationPermission(context);
                  },
                  onRequestBatteryOptimizationExemption: () {
                    _requestBatteryOptimizationExemption(context);
                  },
                  onRequestCameraPermission: () {
                    _requestCameraPermission(context);
                  },
                  onRequestActivityRecognitionPermission: () {
                    _requestActivityRecognitionPermission(context);
                  },
                  onRunOnboarding: () async {
                    await ref
                        .read(onboardingControllerProvider.notifier)
                        .resetOnboarding();
                  },
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
    final edited = await AlarmEditorSheet.show(
      context,
      alarm: draft,
      engineStatus: engineStatus,
    );
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
    AlarmEngineStatus? engineStatus,
  ) async {
    final edited = await AlarmEditorSheet.show(
      context,
      alarm: alarm,
      engineStatus: engineStatus,
    );
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

  Future<void> _requestBatteryOptimizationExemption(
    BuildContext context,
  ) async {
    await _runRepositoryAction(
      context,
      () => ref
          .read(alarmRepositoryProvider)
          .requestBatteryOptimizationExemption(),
    );
  }

  Future<void> _requestCameraPermission(BuildContext context) async {
    await _runRepositoryAction(
      context,
      () => ref.read(alarmRepositoryProvider).requestCameraPermission(),
    );
  }

  Future<void> _requestActivityRecognitionPermission(
    BuildContext context,
  ) async {
    await _runRepositoryAction(
      context,
      () => ref
          .read(alarmRepositoryProvider)
          .requestActivityRecognitionPermission(),
    );
  }
}

class _AlarmDashboardPage extends StatelessWidget {
  const _AlarmDashboardPage({
    required this.alarms,
    required this.engineStatus,
    required this.nextAlarmCountdownText,
    required this.onRequestExactAlarmPermission,
    required this.onRequestNotificationPermission,
    required this.onOpenSettings,
    required this.onEdit,
    required this.onDelete,
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
  final Future<void> Function(AlarmSpec alarm, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
        children: [
          _DashboardHeader(
            onOpenSettings: onOpenSettings,
            countdownText: nextAlarmCountdownText,
          ),
          const SizedBox(height: 18),
          _PermissionBannerRow(
            engineStatus: engineStatus,
            onRequestExactAlarmPermission: onRequestExactAlarmPermission,
            onRequestNotificationPermission: onRequestNotificationPermission,
          ),
          const SizedBox(height: 22),
          const NeoSectionTitle(title: 'Your alarms'),
          const SizedBox(height: 14),
          _AlarmListSection(
            alarms: alarms,
            onEdit: onEdit,
            onDelete: onDelete,
            onToggle: onToggle,
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.onOpenSettings,
    required this.countdownText,
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

class _PermissionBannerRow extends StatelessWidget {
  const _PermissionBannerRow({
    required this.engineStatus,
    required this.onRequestExactAlarmPermission,
    required this.onRequestNotificationPermission,
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
                  'Create your first one-time or repeating alarm.',
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
    final isWorkingWeek =
        alarm.weekdays.isEmpty ||
        alarm.weekdays.every(
          (weekday) => weekday.isoValue >= 1 && weekday.isoValue <= 5,
        );

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
                      NeoPill(
                        label: alarm.label,
                        backgroundColor: alarm.enabled
                            ? isWorkingWeek
                                  ? NeoColors.primary
                                  : NeoColors.cyan
                            : NeoColors.muted,
                      ),
                      const SizedBox(height: 12),
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
                              text: MediaQuery.alwaysUse24HourFormatOf(context)
                                  ? ''
                                  : ' ${localizations.formatTimeOfDay(TimeOfDay(hour: alarm.hour, minute: alarm.minute), alwaysUse24HourFormat: false).split(' ').last}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                NeoToggle(
                  value: alarm.enabled,
                  onChanged: (enabled) {
                    onToggle(enabled);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
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
            _InfoRow(
              label: 'Next',
              value: nextTrigger == null
                  ? 'Not scheduled'
                  : '${_weekdayLabel(nextTrigger.weekday)}, ${nextTrigger.month}/${nextTrigger.day} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(nextTrigger), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}',
            ),
            const SizedBox(height: 8),
            _InfoRow(label: 'Timezone', value: alarm.timezoneId),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Snooze',
              value:
                  '${alarm.snoozeDurationMinutes} min | ${alarm.maxSnoozes} max',
            ),
            const SizedBox(height: 8),
            _InfoRow(label: 'Tone', value: alarm.ringtoneSummary),
            const SizedBox(height: 8),
            _InfoRow(label: 'Dismiss', value: alarm.missionSummary),
            const SizedBox(height: 16),
            Row(
              children: [
                NeoSquareIconButton(
                  icon: Icons.edit,
                  size: 42,
                  backgroundColor: NeoColors.panel,
                  onPressed: () {
                    onEdit();
                  },
                ),
                const SizedBox(width: 10),
                NeoSquareIconButton(
                  icon: Icons.delete,
                  size: 42,
                  backgroundColor: NeoColors.warm,
                  foregroundColor: Colors.red.shade700,
                  onPressed: () {
                    onDelete();
                  },
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
          width: 72,
          child: Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: NeoColors.subtext,
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

String? _nextAlarmCountdownText(List<AlarmSpec> alarms) {
  final soonestAlarm = alarms
      .where((alarm) => alarm.enabled && alarm.nextTriggerAtLocal != null)
      .fold<AlarmSpec?>(
        null,
        (currentSoonest, alarm) {
          if (currentSoonest == null) {
            return alarm;
          }

          final currentTrigger = currentSoonest.nextTriggerAtLocal!;
          final nextTrigger = alarm.nextTriggerAtLocal!;
          return nextTrigger.isBefore(currentTrigger) ? alarm : currentSoonest;
        },
      );

  final trigger = soonestAlarm?.nextTriggerAtLocal;
  if (trigger == null) {
    return null;
  }

  return formatAlarmCountdown(trigger, prefix: 'Next alarm in');
}
