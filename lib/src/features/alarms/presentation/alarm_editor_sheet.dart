import 'dart:async';

import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:neoalarm/src/features/alarms/application/alarm_list_controller.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_countdown_formatter.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_location_trigger.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_spec.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_tone.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_timezone.dart';
import 'package:neoalarm/src/features/alarms/presentation/qr_target_capture_screen.dart';
import 'package:neoalarm/src/features/alarms/presentation/widgets/alarm_custom_tone_panel.dart';
import 'package:neoalarm/src/features/alarms/presentation/widgets/alarm_editor_widgets.dart';
import 'package:neoalarm/src/features/alarms/presentation/widgets/alarm_time_picker_sheet.dart';
import 'package:neoalarm/src/features/alarms/presentation/widgets/alarm_timezone_picker_sheet.dart';
import 'package:neoalarm/src/features/location_alarms/presentation/location_alarm_setup_screen.dart';
import 'package:neoalarm/src/features/missions/application/mission_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

class AlarmEditorSheet extends ConsumerStatefulWidget {
  const AlarmEditorSheet({required this.alarm, this.engineStatus, super.key});

  final AlarmSpec alarm;
  final AlarmEngineStatus? engineStatus;

  static Future<AlarmSpec?> show(
    BuildContext context, {
    required AlarmSpec alarm,
    AlarmEngineStatus? engineStatus,
  }) {
    return showModalBottomSheet<AlarmSpec>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AlarmEditorSheet(alarm: alarm, engineStatus: engineStatus),
    );
  }

  @override
  ConsumerState<AlarmEditorSheet> createState() => _AlarmEditorSheetState();
}

class _AlarmEditorSheetState extends ConsumerState<AlarmEditorSheet> {
  late final TextEditingController _labelController;
  late TimeOfDay _time;
  late bool _enabled;
  late bool _followsDeviceTimezone;
  late String _timezoneId;
  late Set<AlarmWeekday> _selectedWeekdays;
  late AlarmLocationTrigger? _locationTrigger;
  late AlarmRingtone _ringtone;
  late String? _selectedCustomToneId;
  late bool _volumeRampEnabled;
  late bool _extraLoudEnabled;
  late int _snoozeDurationMinutes;
  late int _maxSnoozes;
  late MissionSpec _mission;
  List<AlarmTone> _customTones = const [];
  List<String> _availableTimezones = const [];
  bool _tonesLoading = true;
  bool _timezonesLoading = false;
  String? _toneLibraryError;
  Timer? _countdownTicker;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.alarm.label);
    _time = TimeOfDay(hour: widget.alarm.hour, minute: widget.alarm.minute);
    _enabled = widget.alarm.enabled;
    _followsDeviceTimezone = widget.alarm.followsDeviceTimezone;
    _timezoneId = widget.alarm.timezoneId;
    _selectedWeekdays = widget.alarm.weekdays.toSet();
    _locationTrigger = widget.alarm.locationTrigger;
    _ringtone = widget.alarm.ringtone;
    _selectedCustomToneId = widget.alarm.customToneId;
    _volumeRampEnabled = widget.alarm.volumeRampEnabled;
    _extraLoudEnabled = widget.alarm.extraLoudEnabled;
    _snoozeDurationMinutes = widget.alarm.snoozeDurationMinutes;
    _maxSnoozes = widget.alarm.maxSnoozes;
    _mission = widget.alarm.mission;
    _countdownTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    unawaited(_loadCustomTones());
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final diagnostics = widget.engineStatus;
    final missionRegistry = ref.read(missionRegistryProvider);
    final isLocationAlarm = widget.alarm.isLocationAlarm;
    final locationTrigger = _locationTrigger;
    final availableMissionTypes = missionRegistry.editorMissionTypes(
      diagnostics: diagnostics,
    );
    final missionTypes = [
      ...availableMissionTypes,
      if (!missionRegistry.isConfigurableForEditor(
            _mission.type,
            diagnostics: diagnostics,
          ) &&
          !availableMissionTypes.contains(_mission.type))
        _mission.type,
    ];
    final amPmLabel = _time.period == DayPeriod.am ? 'AM' : 'PM';
    final alarmPreviewText = _alarmPreviewCountdownText();

    return FractionallySizedBox(
      heightFactor: 0.96,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          12 + mediaQuery.viewInsets.bottom,
        ),
        child: NeoPanel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    NeoSquareIconButton(
                      icon: Icons.close,
                      size: 42,
                      onPressed: () {
                        Navigator.of(context).maybePop();
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.alarm.nextTriggerAtUtc == null
                            ? 'NEW ALARM'
                            : 'EDIT ALARM',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              if (isLocationAlarm)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  decoration: BoxDecoration(
                    color: Color(0x2200D1FF),
                    border: Border(
                      top: BorderSide(color: NeoColors.ink, width: 3),
                      bottom: BorderSide(color: NeoColors.ink, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LOCATION ALARM',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        locationTrigger?.label ?? 'Destination not configured',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        locationTrigger == null
                            ? 'Pick a destination before saving this alarm.'
                            : '${locationTrigger.radiusSummary} | ${locationTrigger.health.label}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: NeoColors.subtext,
                        ),
                      ),
                      if (locationTrigger != null) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: NeoActionButton(
                                label: 'Change destination',
                                compact: true,
                                backgroundColor: NeoColors.primary,
                                onPressed: _editLocationTrigger,
                              ),
                            ),
                            if (locationTrigger.health ==
                                AlarmLocationHealth.geofenceNotRegistered) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: NeoActionButton(
                                  label: 'Retry arming',
                                  compact: true,
                                  backgroundColor: NeoColors.cyan,
                                  onPressed: _retryLocationAlarm,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  decoration: BoxDecoration(
                    color: Color(0x22FFFF00),
                    border: Border(
                      top: BorderSide(color: NeoColors.ink, width: 3),
                      bottom: BorderSide(color: NeoColors.ink, width: 3),
                    ),
                  ),
                  child: InkWell(
                    onTap: _pickTime,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AlarmTimeBlock(
                              label: _time.hourOfPeriod.toString().padLeft(
                                2,
                                '0',
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                ':',
                                style: theme.textTheme.displayMedium,
                              ),
                            ),
                            AlarmTimeBlock(
                              label: _time.minute.toString().padLeft(2, '0'),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              children: [
                                AlarmPeriodChip(
                                  label: 'AM',
                                  active: amPmLabel == 'AM',
                                ),
                                const SizedBox(height: 8),
                                AlarmPeriodChip(
                                  label: 'PM',
                                  active: amPmLabel == 'PM',
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          alarmPreviewText,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: NeoColors.subtext,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isLocationAlarm &&
                          diagnostics != null &&
                          !diagnostics.canScheduleExactAlarms) ...[
                        const AlarmEditorWarning(
                          title: 'Exact alarms are not ready',
                          detail:
                              'You can still save the alarm, but enabling it will fail until exact-alarm access is available.',
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text('LABEL', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _labelController,
                        decoration: const InputDecoration(
                          hintText: 'Wake up call',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (isLocationAlarm && locationTrigger != null) ...[
                        const SizedBox(height: 18),
                        AlarmEditorSelector(
                          title: 'DESTINATION DETAILS',
                          child: NeoPanel(
                            color: NeoColors.panel,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AlarmEditorInfoRow(
                                  label: 'Radius',
                                  value: locationTrigger.radiusSummary,
                                ),
                                const SizedBox(height: 10),
                                AlarmEditorInfoRow(
                                  label: 'Status',
                                  value: locationTrigger.health.label,
                                ),
                                const SizedBox(height: 10),
                                AlarmEditorInfoRow(
                                  label: 'Mode',
                                  value:
                                      'One-shot arrival alarm near the saved destination.',
                                ),
                                if (!locationTrigger.isHealthy &&
                                    locationTrigger.health !=
                                        AlarmLocationHealth
                                            .geofenceNotRegistered) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    'Device readiness for location alarms now lives in Settings.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: NeoColors.subtext,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 18),
                        Text('REPEAT', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: AlarmWeekday.values
                              .map(
                                (weekday) => NeoDayChip(
                                  label: weekday.shortLabel.substring(0, 1),
                                  selected: _selectedWeekdays.contains(weekday),
                                  onTap: () {
                                    setState(() {
                                      if (_selectedWeekdays.contains(weekday)) {
                                        _selectedWeekdays.remove(weekday);
                                      } else {
                                        _selectedWeekdays.add(weekday);
                                      }
                                    });
                                  },
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                      if (!isLocationAlarm) ...[
                        const SizedBox(height: 18),
                        AlarmEditorSelector(
                          title: 'TIME ZONE',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<_AlarmTimezoneMode>(
                                initialValue: _followsDeviceTimezone
                                    ? _AlarmTimezoneMode.device
                                    : _AlarmTimezoneMode.specific,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                ),
                                icon: const Icon(Icons.expand_more),
                                items: const [
                                  DropdownMenuItem<_AlarmTimezoneMode>(
                                    value: _AlarmTimezoneMode.device,
                                    child: Text('DEVICE TIME'),
                                  ),
                                  DropdownMenuItem<_AlarmTimezoneMode>(
                                    value: _AlarmTimezoneMode.specific,
                                    child: Text('SPECIFIC TIMEZONE'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _followsDeviceTimezone =
                                        value == _AlarmTimezoneMode.device;
                                    if (_followsDeviceTimezone) {
                                      _timezoneId = _deviceTimezoneId;
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _followsDeviceTimezone
                                    ? 'Follows your phone timezone when you travel.'
                                    : 'Stays pinned to the selected timezone. Useful for reminders like 9:00 AM Toronto time.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: NeoColors.subtext,
                                ),
                              ),
                              if (!_followsDeviceTimezone) ...[
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: _pickTimezone,
                                  child: NeoPanel(
                                    color: NeoColors.panel,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                formatTimezoneSummary(
                                                  _timezoneId,
                                                ).toUpperCase(),
                                                style:
                                                    theme.textTheme.titleMedium,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _timezoneId,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: NeoColors.subtext,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        if (_timezonesLoading)
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                            ),
                                          )
                                        else
                                          const Icon(Icons.travel_explore),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      AlarmEditorSelector(
                        title: 'RINGTONE',
                        child: DropdownButtonFormField<AlarmRingtone>(
                          initialValue: _ringtone,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                          icon: const Icon(Icons.expand_more),
                          items: AlarmRingtone.values
                              .map(
                                (ringtone) => DropdownMenuItem<AlarmRingtone>(
                                  value: ringtone,
                                  child: Text(ringtone.label.toUpperCase()),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _ringtone = value;
                              if (_ringtone != AlarmRingtone.customTone) {
                                _selectedCustomToneId = null;
                              }
                            });
                          },
                        ),
                      ),
                      if (_ringtone == AlarmRingtone.customTone) ...[
                        const SizedBox(height: 14),
                        AlarmCustomTonePanel(
                          tones: _customTones,
                          tonesLoading: _tonesLoading,
                          toneLibraryError: _toneLibraryError,
                          selectedToneId: _selectedCustomToneId,
                          onToneSelected: (value) {
                            setState(() {
                              _selectedCustomToneId = value;
                            });
                          },
                          onImportTone: _importCustomTone,
                          onManageTones: _customTones.isEmpty
                              ? null
                              : _manageCustomTones,
                        ),
                      ],
                      const SizedBox(height: 14),
                      AlarmEditorToggleRow(
                        title: 'VOLUME RAMP UP',
                        detail:
                            'Start softer and climb toward full alarm volume while ringing.',
                        value: _volumeRampEnabled,
                        onChanged: (value) {
                          setState(() {
                            _volumeRampEnabled = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      AlarmEditorToggleRow(
                        title: 'EXTRA LOUD MODE',
                        detail:
                            'Applies a small speaker-only loudness boost. Headphones and Bluetooth stay untouched.',
                        value: _extraLoudEnabled,
                        onChanged: (value) {
                          setState(() {
                            _extraLoudEnabled = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      AlarmEditorSelector(
                        title: 'SNOOZE',
                        child: DropdownButtonFormField<int>(
                          initialValue: _snoozeDurationMinutes,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                          icon: const Icon(Icons.expand_more),
                          items: const [5, 9, 10, 15, 20]
                              .map(
                                (minutes) => DropdownMenuItem<int>(
                                  value: minutes,
                                  child: Text('$minutes MINUTES'),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _snoozeDurationMinutes = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      AlarmEditorSelector(
                        title: 'DISMISSAL',
                        child: DropdownButtonFormField<AlarmMissionType>(
                          initialValue: _mission.type,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                          icon: const Icon(Icons.expand_more),
                          items: missionTypes
                              .map((missionType) {
                                final option = _missionOptionFor(
                                  missionType,
                                  diagnostics,
                                );
                                return DropdownMenuItem<AlarmMissionType>(
                                  value: missionType,
                                  child: Text(option.title.toUpperCase()),
                                );
                              })
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _mission = _mission.copyWith(type: value);
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _missionOptionFor(_mission.type, diagnostics).detail,
                        style: theme.textTheme.bodySmall,
                      ),
                      if ((diagnostics?.hasStepSensor ?? false) &&
                          !(diagnostics?.activityRecognitionGranted ??
                              true)) ...[
                        const SizedBox(height: 12),
                        const AlarmEditorWarning(
                          title: 'Steps mission hidden',
                          detail:
                              'Grant or re-enable activity recognition from Settings > Device readiness before steps alarms can be configured.',
                        ),
                      ],
                      if ((diagnostics?.hasCamera ?? false) &&
                          !(diagnostics?.cameraPermissionGranted ?? true)) ...[
                        const SizedBox(height: 12),
                        const AlarmEditorWarning(
                          title: 'QR mission hidden',
                          detail:
                              'Grant or re-enable camera permission from Settings > Device readiness before QR-backed alarms can be configured.',
                        ),
                      ],
                      if (_mission.type == AlarmMissionType.math) ...[
                        const SizedBox(height: 14),
                        AlarmEditorSelector(
                          title: 'MATH DIFFICULTY',
                          child: DropdownButtonFormField<MathMissionDifficulty>(
                            initialValue: _mission.mathDifficulty,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            icon: const Icon(Icons.expand_more),
                            items: MathMissionDifficulty.values
                                .map(
                                  (difficulty) =>
                                      DropdownMenuItem<MathMissionDifficulty>(
                                        value: difficulty,
                                        child: Text(
                                          difficulty.label.toUpperCase(),
                                        ),
                                      ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                _mission = _mission.copyWith(
                                  mathDifficulty: value,
                                );
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        AlarmEditorSelector(
                          title: 'PROBLEM COUNT',
                          child: DropdownButtonFormField<int>(
                            initialValue: _mission.mathProblemCount,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            icon: const Icon(Icons.expand_more),
                            items: const [1, 2, 3, 4, 5]
                                .map(
                                  (count) => DropdownMenuItem<int>(
                                    value: count,
                                    child: Text(
                                      '$count ${count == 1 ? 'PROBLEM' : 'PROBLEMS'}',
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                _mission = _mission.copyWith(
                                  mathProblemCount: value,
                                );
                              });
                            },
                          ),
                        ),
                      ] else if (_mission.type == AlarmMissionType.steps) ...[
                        const SizedBox(height: 14),
                        AlarmEditorSelector(
                          title: 'STEP GOAL',
                          child: DropdownButtonFormField<int>(
                            initialValue: _mission.stepGoal,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            icon: const Icon(Icons.expand_more),
                            items: const [10, 20, 30, 50, 100]
                                .map(
                                  (count) => DropdownMenuItem<int>(
                                    value: count,
                                    child: Text('$count STEPS'),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                _mission = _mission.copyWith(stepGoal: value);
                              });
                            },
                          ),
                        ),
                      ] else if (_mission.type == AlarmMissionType.qr) ...[
                        const SizedBox(height: 14),
                        NeoPanel(
                          color: NeoColors.panel,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TARGET QR',
                                style: theme.textTheme.labelMedium,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _mission.hasQrTarget
                                    ? 'A QR target is saved for this alarm.'
                                    : 'Scan the QR code this alarm should require before saving.',
                                style: theme.textTheme.bodyMedium,
                              ),
                              if (_mission.hasQrTarget) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _mission.qrTargetValue!,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: NeoActionButton(
                                      label: _mission.hasQrTarget
                                          ? 'Replace target'
                                          : 'Scan target',
                                      backgroundColor: NeoColors.cyan,
                                      onPressed: _captureQrTarget,
                                    ),
                                  ),
                                  if (_mission.hasQrTarget) ...[
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: NeoActionButton(
                                        label: 'Clear target',
                                        backgroundColor: NeoColors.warm,
                                        onPressed: () {
                                          setState(() {
                                            _mission = const MissionSpec.qr();
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text('MAX SNOOZES', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [0, 1, 2, 3, 4, 5]
                            .map(
                              (count) => AlarmCountChip(
                                count: count,
                                selected: _maxSnoozes == count,
                                onTap: () {
                                  setState(() {
                                    _maxSnoozes = count;
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Text('ENABLED', style: theme.textTheme.titleMedium),
                          const Spacer(),
                          NeoToggle(
                            value: _enabled,
                            onChanged: (value) {
                              setState(() {
                                _enabled = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: NeoActionButton(
                  label: 'Save alarm',
                  expand: true,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final selected = await AlarmTimePickerSheet.show(
      context,
      initialTime: _time,
      countdownText: _alarmPreviewCountdownText(),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _time = selected;
    });
  }

  String _alarmPreviewCountdownText() {
    final nextTrigger = computeNextAlarmPreview(
      hour: _time.hour,
      minute: _time.minute,
      weekdays: _selectedWeekdays,
    );
    return formatAlarmCountdown(nextTrigger);
  }

  void _save() {
    if (_mission.type == AlarmMissionType.qr && !_mission.hasQrTarget) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan a target QR code before saving this alarm.'),
        ),
      );
      return;
    }

    if (widget.alarm.isLocationAlarm && _locationTrigger == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pick a destination before saving this location alarm.',
          ),
        ),
      );
      return;
    }

    if (_ringtone == AlarmRingtone.customTone &&
        _selectedCustomToneId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Import or select a custom tone before saving this alarm.',
          ),
        ),
      );
      return;
    }

    final normalizedWeekdays = _selectedWeekdays.toList()
      ..sort((left, right) => left.isoValue.compareTo(right.isoValue));

    Navigator.of(context).pop(
      widget.alarm.copyWith(
        label: _labelController.text.trim().isEmpty
            ? (_locationTrigger?.label ?? 'Alarm')
            : _labelController.text.trim(),
        hour: _time.hour,
        minute: _time.minute,
        timezoneId: _followsDeviceTimezone ? _deviceTimezoneId : _timezoneId,
        followsDeviceTimezone: _followsDeviceTimezone,
        enabled: _enabled,
        weekdays: normalizedWeekdays,
        locationTrigger: _locationTrigger,
        ringtone: _ringtone,
        customToneId: _selectedCustomToneId,
        clearCustomToneId: _ringtone != AlarmRingtone.customTone,
        volumeRampEnabled: _volumeRampEnabled,
        extraLoudEnabled: _extraLoudEnabled,
        snoozeDurationMinutes: _snoozeDurationMinutes,
        maxSnoozes: _maxSnoozes,
        mission: _mission,
        clearNextTriggerAtUtc: true,
      ),
    );
  }

  Future<void> _editLocationTrigger() async {
    final existingTrigger = _locationTrigger;
    final nextTrigger = await LocationAlarmSetupScreen.show(
      context,
      initialTrigger: existingTrigger,
    );

    if (!mounted || nextTrigger == null) {
      return;
    }

    final currentLabel = _labelController.text.trim();
    final previousLocationLabel = existingTrigger?.label.trim();
    final shouldFollowDestinationLabel =
        currentLabel.isEmpty ||
        currentLabel == 'Alarm' ||
        (previousLocationLabel != null &&
            currentLabel == previousLocationLabel);

    setState(() {
      _locationTrigger = nextTrigger;
      if (shouldFollowDestinationLabel) {
        _labelController.text = nextTrigger.label;
      }
    });
  }

  Future<void> _retryLocationAlarm() async {
    try {
      final refreshed = await ref
          .read(alarmRepositoryProvider)
          .refreshLocationAlarm(widget.alarm.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _locationTrigger = refreshed.locationTrigger;
      });
      ref.invalidate(alarmListControllerProvider);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to retry arming: $error')));
    }
  }

  _MissionOption _missionOptionFor(
    AlarmMissionType missionType,
    AlarmEngineStatus? diagnostics,
  ) {
    return switch (missionType) {
      AlarmMissionType.none => const _MissionOption(
        title: 'Direct dismiss',
        detail: 'The alarm can be dismissed from the active alarm screen.',
        enabled: true,
      ),
      AlarmMissionType.math => const _MissionOption(
        title: 'Math mission',
        detail:
            'Solve generated math problems to dismiss the alarm. Difficulty and problem count are configurable below.',
        enabled: true,
      ),
      AlarmMissionType.steps => _MissionOption(
        title: 'Steps mission',
        detail: !((diagnostics?.hasStepSensor) ?? false)
            ? 'This device does not expose a live step detector.'
            : !((diagnostics?.activityRecognitionGranted) ?? false)
            ? 'Grant or re-enable activity recognition from Settings before saving a steps-backed alarm.'
            : 'Walk a configurable number of steps to dismiss the alarm.',
        enabled:
            (diagnostics?.hasStepSensor ?? false) &&
            (diagnostics?.activityRecognitionGranted ?? false),
      ),
      AlarmMissionType.qr => _MissionOption(
        title: 'QR mission',
        detail: !((diagnostics?.hasCamera) ?? false)
            ? 'This device does not report camera availability.'
            : !((diagnostics?.cameraPermissionGranted) ?? false)
            ? 'Grant or re-enable camera permission from Settings before saving a QR-backed alarm.'
            : 'Scan a saved QR target to dismiss the alarm.',
        enabled: diagnostics?.cameraReady ?? false,
      ),
    };
  }

  Future<void> _captureQrTarget() async {
    final capturedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => const QrTargetCaptureScreen(),
      ),
    );

    if (!mounted || capturedValue == null) {
      return;
    }

    setState(() {
      _mission = _mission.copyWith(qrTargetValue: capturedValue);
    });
  }

  Future<void> _loadCustomTones() async {
    setState(() {
      _tonesLoading = true;
      _toneLibraryError = null;
    });

    try {
      final tones = await ref.read(alarmRepositoryProvider).listCustomTones();
      if (!mounted) {
        return;
      }
      setState(() {
        _customTones = tones;
        _tonesLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _tonesLoading = false;
        _toneLibraryError = '$error';
      });
    }
  }

  String get _deviceTimezoneId =>
      widget.engineStatus?.timezoneId.isNotEmpty == true
      ? widget.engineStatus!.timezoneId
      : widget.alarm.timezoneId;

  Future<void> _ensureAvailableTimezonesLoaded() async {
    if (_availableTimezones.isNotEmpty || _timezonesLoading) {
      return;
    }

    setState(() {
      _timezonesLoading = true;
    });

    try {
      final timezones = await ref
          .read(alarmRepositoryProvider)
          .listAvailableTimezones();
      if (!mounted) {
        return;
      }
      setState(() {
        _availableTimezones = timezones;
        _timezonesLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _timezonesLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load timezones: $error')),
      );
    }
  }

  Future<void> _pickTimezone() async {
    await _ensureAvailableTimezonesLoaded();
    if (!mounted || _availableTimezones.isEmpty) {
      return;
    }

    final selected = await AlarmTimezonePickerSheet.show(
      context,
      timezones: _availableTimezones,
      initialTimezoneId: _timezoneId,
      currentTimezoneId: _deviceTimezoneId,
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _timezoneId = selected;
    });
  }

  Future<void> _importCustomTone() async {
    try {
      final imported = await ref
          .read(alarmRepositoryProvider)
          .importCustomTone();
      if (!mounted || imported == null) {
        return;
      }
      await _loadCustomTones();
      if (!mounted) {
        return;
      }
      setState(() {
        _ringtone = AlarmRingtone.customTone;
        _selectedCustomToneId = imported.id;
      });
      ref.invalidate(alarmListControllerProvider);
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? error.code)));
    }
  }

  Future<void> _manageCustomTones() async {
    await AlarmToneManagementSheet.show(
      context,
      tones: _customTones,
      onDelete: (tone) async {
        await ref.read(alarmRepositoryProvider).deleteCustomTone(tone.id);
        await _loadCustomTones();
        ref.invalidate(alarmListControllerProvider);
        if (_selectedCustomToneId == tone.id && mounted) {
          setState(() {
            _selectedCustomToneId = null;
          });
        }
      },
    );
  }
}

enum _AlarmTimezoneMode { device, specific }

class _MissionOption {
  const _MissionOption({
    required this.title,
    required this.detail,
    required this.enabled,
  });

  final String title;
  final String detail;
  final bool enabled;
}
