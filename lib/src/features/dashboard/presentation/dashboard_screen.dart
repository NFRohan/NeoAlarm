import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:neoalarm/src/features/alarms/application/alarm_list_controller.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_location_trigger.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_spec.dart';
import 'package:neoalarm/src/features/alarms/presentation/alarm_editor_sheet.dart';
import 'package:neoalarm/src/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:neoalarm/src/features/location_alarms/presentation/location_alarm_setup_screen.dart';
import 'package:neoalarm/src/features/onboarding/application/onboarding_controller.dart';
import 'package:neoalarm/src/features/settings/application/location_provider_settings_controller.dart';
import 'package:neoalarm/src/features/settings/application/theme_mode_controller.dart';
import 'package:neoalarm/src/features/settings/presentation/settings_screen.dart';

enum _DashboardTab { alarms, settings }

enum _AlarmCreateMode { time, location }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  _DashboardTab _selectedTab = _DashboardTab.alarms;
  Timer? _countdownTicker;
  String? _lastPromptedLocationRepairKey;
  bool _locationRepairPromptShowing = false;

  @override
  void initState() {
    super.initState();
    _countdownTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alarms = ref.watch(alarmListControllerProvider);
    final engineStatus = ref.watch(alarmEngineStatusProvider);
    final themeMode = ref.watch(appThemeModeControllerProvider);
    final locationProviderSettings = ref.watch(
      locationProviderSettingsControllerProvider,
    );
    final showAddAlarm = _selectedTab == _DashboardTab.alarms;
    final alarmValues = alarms.asData?.value;
    if (alarmValues != null) {
      _maybeScheduleLocationRepairPrompt(context, ref, alarmValues);
    }

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
              ? AlarmDashboardPage(
                  key: const ValueKey('alarms-tab'),
                  alarms: alarms,
                  engineStatus: engineStatus,
                  nextAlarmCountdownText: nextAlarmCountdownText(
                    alarmValues ?? const [],
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
                  onSkipNext: (alarm) =>
                      _skipNextOccurrence(context, ref, alarm),
                  onClearSkippedOccurrence: (alarm) =>
                      _clearSkippedOccurrence(context, ref, alarm),
                  onRepairLocationAlarm: (alarm) =>
                      _repairLocationAlarm(context, ref, alarm),
                  onToggle: (alarm, enabled) =>
                      _setEnabled(context, ref, alarm, enabled),
                )
              : SettingsScreen(
                  key: const ValueKey('settings-tab'),
                  status: engineStatus,
                  themeMode: themeMode,
                  locationProviderSettings: locationProviderSettings,
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
                  onOpenLocationSettings: () {
                    _openLocationSettings(context);
                  },
                  onRequestForegroundLocationPermission: () {
                    _requestForegroundLocationPermission(context);
                  },
                  onRequestBackgroundLocationPermission: () {
                    _requestBackgroundLocationPermission(context);
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
                  onSaveOpenCageApiKey: (token) => ref
                      .read(locationProviderSettingsControllerProvider.notifier)
                      .setOpenCageApiKey(token),
                  onClearOpenCageApiKey: () => ref
                      .read(locationProviderSettingsControllerProvider.notifier)
                      .clearOpenCageApiKey(),
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
    final mode = await _pickAlarmCreateMode(context);
    if (mode == null || !context.mounted) {
      return;
    }

    if (mode == _AlarmCreateMode.location) {
      final locationTrigger = await LocationAlarmSetupScreen.show(context);
      if (locationTrigger == null || !context.mounted) {
        return;
      }

      final draft = AlarmSpec.createLocationDraft(
        timezoneId: engineStatus?.timezoneId ?? 'UTC',
        locationTrigger: locationTrigger,
      );

      await _runRepositoryAction(
        context,
        () => ref.read(alarmListControllerProvider.notifier).saveAlarm(draft),
      );
      return;
    }

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
    if (alarm.isLocationAlarm) {
      final locationTrigger = await LocationAlarmSetupScreen.show(
        context,
        initialTrigger: alarm.locationTrigger,
      );
      if (locationTrigger == null || !context.mounted) {
        return;
      }

      final edited = alarm.copyWith(
        label: locationTrigger.label,
        locationTrigger: locationTrigger,
      );

      await _runRepositoryAction(
        context,
        () => ref.read(alarmListControllerProvider.notifier).saveAlarm(edited),
      );
      return;
    }

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

  Future<void> _skipNextOccurrence(
    BuildContext context,
    WidgetRef ref,
    AlarmSpec alarm,
  ) async {
    await _runRepositoryAction(
      context,
      () => ref
          .read(alarmListControllerProvider.notifier)
          .skipNextOccurrence(alarm.id),
    );
  }

  Future<void> _clearSkippedOccurrence(
    BuildContext context,
    WidgetRef ref,
    AlarmSpec alarm,
  ) async {
    await _runRepositoryAction(
      context,
      () => ref
          .read(alarmListControllerProvider.notifier)
          .clearSkippedOccurrence(alarm.id),
    );
  }

  void _maybeScheduleLocationRepairPrompt(
    BuildContext context,
    WidgetRef ref,
    List<AlarmSpec> alarms,
  ) {
    if (_selectedTab != _DashboardTab.alarms) {
      return;
    }

    final alarm = _firstPromptableLocationAlarm(alarms);
    if (alarm == null) {
      _lastPromptedLocationRepairKey = null;
      return;
    }

    final health = alarm.locationTrigger!.health;
    final promptKey = '${alarm.id}:${health.id}';
    if (_locationRepairPromptShowing ||
        _lastPromptedLocationRepairKey == promptKey) {
      return;
    }

    _lastPromptedLocationRepairKey = promptKey;
    _locationRepairPromptShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _selectedTab != _DashboardTab.alarms) {
        _locationRepairPromptShowing = false;
        return;
      }

      await _showLocationRepairPrompt(context, ref, alarm);
      if (mounted) {
        _locationRepairPromptShowing = false;
      }
    });
  }

  AlarmSpec? _firstPromptableLocationAlarm(List<AlarmSpec> alarms) {
    for (final alarm in alarms) {
      if (!alarm.enabled || !alarm.isLocationAlarm) {
        continue;
      }

      final health = alarm.locationTrigger?.health;
      if (health != null && _shouldPromptForLocationHealth(health)) {
        return alarm;
      }
    }

    return null;
  }

  bool _shouldPromptForLocationHealth(AlarmLocationHealth health) {
    return switch (health) {
      AlarmLocationHealth.unknown ||
      AlarmLocationHealth.noForegroundPermission ||
      AlarmLocationHealth.noBackgroundPermission ||
      AlarmLocationHealth.locationDisabled ||
      AlarmLocationHealth.geofenceNotRegistered ||
      AlarmLocationHealth.batteryRestricted => true,
      AlarmLocationHealth.healthy ||
      AlarmLocationHealth.rearmPending ||
      AlarmLocationHealth.waitingForExit ||
      AlarmLocationHealth.playServicesUnavailable ||
      AlarmLocationHealth.lowLocationConfidence => false,
    };
  }

  Future<void> _showLocationRepairPrompt(
    BuildContext context,
    WidgetRef ref,
    AlarmSpec alarm,
  ) async {
    final locationTrigger = alarm.locationTrigger;
    if (locationTrigger == null) {
      return;
    }

    final health = locationTrigger.health;
    final actionLabel = health.repairActionLabel;
    if (actionLabel == null) {
      return;
    }

    final alarmLabel = alarm.label.trim().isEmpty
        ? 'This location alarm'
        : alarm.label.trim();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Location alarm needs attention'),
          content: Text(
            '$alarmLabel may not trigger right now: ${health.label}.\n\n'
            '${_locationRepairPromptDetail(health)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );

    if (result != true || !context.mounted) {
      return;
    }

    await _repairLocationAlarm(context, ref, alarm);
  }

  String _locationRepairPromptDetail(AlarmLocationHealth health) {
    return switch (health) {
      AlarmLocationHealth.unknown =>
        'NeoAlarm could not verify this alarm state. Recheck readiness before relying on it.',
      AlarmLocationHealth.noForegroundPermission =>
        'Android location permission was revoked, so NeoAlarm cannot evaluate your position.',
      AlarmLocationHealth.noBackgroundPermission =>
        'Background location access is missing, so Android may not deliver travel triggers while NeoAlarm is closed.',
      AlarmLocationHealth.locationDisabled =>
        'Location services are off, so Android cannot tell when you reach the destination.',
      AlarmLocationHealth.geofenceNotRegistered =>
        'The destination geofence is not armed. Retry arming before relying on this alarm.',
      AlarmLocationHealth.batteryRestricted =>
        'Battery restrictions can delay location callbacks on this device.',
      AlarmLocationHealth.healthy ||
      AlarmLocationHealth.rearmPending ||
      AlarmLocationHealth.waitingForExit ||
      AlarmLocationHealth.playServicesUnavailable ||
      AlarmLocationHealth.lowLocationConfidence => '',
    };
  }

  Future<void> _repairLocationAlarm(
    BuildContext context,
    WidgetRef ref,
    AlarmSpec alarm,
  ) async {
    final health = alarm.locationTrigger?.health;
    if (health == null) {
      return;
    }

    switch (health) {
      case AlarmLocationHealth.unknown:
        await _runRepositoryAction(
          context,
          () => ref
              .read(alarmListControllerProvider.notifier)
              .refreshLocationAlarm(alarm.id),
        );
        return;
      case AlarmLocationHealth.rearmPending:
        return;
      case AlarmLocationHealth.noForegroundPermission:
        await _runRepositoryAction(
          context,
          () => ref
              .read(alarmRepositoryProvider)
              .requestForegroundLocationPermission(),
        );
        break;
      case AlarmLocationHealth.noBackgroundPermission:
        await _runRepositoryAction(
          context,
          () => ref
              .read(alarmRepositoryProvider)
              .requestBackgroundLocationPermission(),
        );
        break;
      case AlarmLocationHealth.locationDisabled:
        await _runRepositoryAction(
          context,
          () => ref.read(alarmRepositoryProvider).openLocationSettings(),
        );
        return;
      case AlarmLocationHealth.geofenceNotRegistered:
        await _runRepositoryAction(
          context,
          () => ref
              .read(alarmListControllerProvider.notifier)
              .refreshLocationAlarm(alarm.id),
        );
        return;
      case AlarmLocationHealth.waitingForExit:
        return;
      case AlarmLocationHealth.batteryRestricted:
        await _runRepositoryAction(
          context,
          () => ref
              .read(alarmRepositoryProvider)
              .requestBatteryOptimizationExemption(),
        );
        return;
      case AlarmLocationHealth.playServicesUnavailable:
      case AlarmLocationHealth.lowLocationConfidence:
      case AlarmLocationHealth.healthy:
        return;
    }

    if (!context.mounted) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!context.mounted) {
      return;
    }

    await _runRepositoryAction(
      context,
      () => ref
          .read(alarmListControllerProvider.notifier)
          .refreshLocationAlarm(alarm.id),
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

  Future<void> _openLocationSettings(BuildContext context) async {
    await _runRepositoryAction(
      context,
      () => ref.read(alarmRepositoryProvider).openLocationSettings(),
    );
  }

  Future<void> _requestForegroundLocationPermission(
    BuildContext context,
  ) async {
    await _runRepositoryAction(
      context,
      () => ref
          .read(alarmRepositoryProvider)
          .requestForegroundLocationPermission(),
    );
  }

  Future<void> _requestBackgroundLocationPermission(
    BuildContext context,
  ) async {
    await _runRepositoryAction(
      context,
      () => ref
          .read(alarmRepositoryProvider)
          .requestBackgroundLocationPermission(),
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

  Future<_AlarmCreateMode?> _pickAlarmCreateMode(BuildContext context) {
    return showModalBottomSheet<_AlarmCreateMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: NeoPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEW ALARM TYPE',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Time alarms are the regular clock-based flow. Location alarms trigger near a saved destination.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: NeoColors.subtext),
                ),
                const SizedBox(height: 16),
                NeoActionButton(
                  label: 'Time alarm',
                  backgroundColor: NeoColors.primary,
                  onPressed: () {
                    Navigator.of(context).pop(_AlarmCreateMode.time);
                  },
                  expand: true,
                ),
                const SizedBox(height: 12),
                NeoActionButton(
                  label: 'Location alarm',
                  backgroundColor: NeoColors.cyan,
                  foregroundColor: NeoColors.accentInk,
                  onPressed: () {
                    Navigator.of(context).pop(_AlarmCreateMode.location);
                  },
                  expand: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
