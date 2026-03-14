import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_countdown_formatter.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_spec.dart';
import 'package:neoalarm/src/features/alarms/presentation/qr_target_capture_screen.dart';
import 'package:neoalarm/src/features/missions/application/mission_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  late Set<AlarmWeekday> _selectedWeekdays;
  late AlarmRingtone _ringtone;
  late bool _volumeRampEnabled;
  late bool _extraLoudEnabled;
  late int _snoozeDurationMinutes;
  late int _maxSnoozes;
  late MissionSpec _mission;
  Timer? _countdownTicker;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.alarm.label);
    _time = TimeOfDay(hour: widget.alarm.hour, minute: widget.alarm.minute);
    _enabled = widget.alarm.enabled;
    _selectedWeekdays = widget.alarm.weekdays.toSet();
    _ringtone = widget.alarm.ringtone;
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
                          _TimeBlock(
                            label: _time.hourOfPeriod.toString().padLeft(2, '0'),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(':', style: theme.textTheme.displayMedium),
                          ),
                          _TimeBlock(
                            label: _time.minute.toString().padLeft(2, '0'),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              _PeriodChip(label: 'AM', active: amPmLabel == 'AM'),
                              const SizedBox(height: 8),
                              _PeriodChip(label: 'PM', active: amPmLabel == 'PM'),
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
                      if (diagnostics != null &&
                          !diagnostics.canScheduleExactAlarms) ...[
                        const _EditorWarning(
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
                      const SizedBox(height: 18),
                      _EditorSelector(
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
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      _EditorToggleRow(
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
                      _EditorToggleRow(
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
                      _EditorSelector(
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
                      _EditorSelector(
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
                        const _EditorWarning(
                          title: 'Steps mission hidden',
                          detail:
                              'Grant or re-enable activity recognition from Settings > Device readiness before steps alarms can be configured.',
                        ),
                      ],
                      if ((diagnostics?.hasCamera ?? false) &&
                          !(diagnostics?.cameraPermissionGranted ?? true)) ...[
                        const SizedBox(height: 12),
                        const _EditorWarning(
                          title: 'QR mission hidden',
                          detail:
                              'Grant or re-enable camera permission from Settings > Device readiness before QR-backed alarms can be configured.',
                        ),
                      ],
                      if (_mission.type == AlarmMissionType.math) ...[
                        const SizedBox(height: 14),
                        _EditorSelector(
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
                        _EditorSelector(
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
                        _EditorSelector(
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
                              (count) => _CountChip(
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
    final selected = await _AlarmTimePickerSheet.show(
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

    final normalizedWeekdays = _selectedWeekdays.toList()
      ..sort((left, right) => left.isoValue.compareTo(right.isoValue));

    Navigator.of(context).pop(
      widget.alarm.copyWith(
        label: _labelController.text.trim().isEmpty
            ? 'Alarm'
            : _labelController.text.trim(),
        hour: _time.hour,
        minute: _time.minute,
        enabled: _enabled,
        weekdays: normalizedWeekdays,
        ringtone: _ringtone,
        volumeRampEnabled: _volumeRampEnabled,
        extraLoudEnabled: _extraLoudEnabled,
        snoozeDurationMinutes: _snoozeDurationMinutes,
        maxSnoozes: _maxSnoozes,
        mission: _mission,
        clearNextTriggerAtUtc: true,
      ),
    );
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
}

class _AlarmTimePickerSheet extends StatefulWidget {
  const _AlarmTimePickerSheet({
    required this.initialTime,
    required this.countdownText,
  });

  final TimeOfDay initialTime;
  final String countdownText;

  static Future<TimeOfDay?> show(
    BuildContext context, {
    required TimeOfDay initialTime,
    required String countdownText,
  }) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.68),
      builder: (context) => _AlarmTimePickerSheet(
        initialTime: initialTime,
        countdownText: countdownText,
      ),
    );
  }

  @override
  State<_AlarmTimePickerSheet> createState() => _AlarmTimePickerSheetState();
}

class _AlarmTimePickerSheetState extends State<_AlarmTimePickerSheet> {
  late int _selectedHour;
  late int _selectedMinute;
  late DayPeriod _selectedPeriod;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  late final FixedExtentScrollController _periodController;
  Timer? _countdownTicker;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hourOfPeriod == 0
        ? 12
        : widget.initialTime.hourOfPeriod;
    _selectedMinute = widget.initialTime.minute;
    _selectedPeriod = widget.initialTime.period;
    _hourController = FixedExtentScrollController(initialItem: _selectedHour - 1);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinute);
    _periodController = FixedExtentScrollController(
      initialItem: _selectedPeriod == DayPeriod.am ? 0 : 1,
    );
    _countdownTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final selectedTime = _selectedTime;
    final countdownText = formatAlarmCountdown(
      computeNextAlarmPreview(
        hour: selectedTime.hour,
        minute: selectedTime.minute,
        weekdays: const [],
      ),
    );

    return FractionallySizedBox(
      heightFactor: 0.7,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          10,
          16,
          10,
          10 + mediaQuery.viewPadding.bottom,
        ),
        child: DecoratedBox(
          decoration: neoPanelDecoration(
            color: NeoColors.paper,
            borderWidth: 3,
            shadowOffset: const Offset(5, 5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                decoration: BoxDecoration(
                  color: NeoColors.cyan,
                  border: Border(
                    bottom: BorderSide(color: NeoColors.ink, width: 3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PICK TIME',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: NeoColors.accentInk,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            localizations.formatTimeOfDay(
                              selectedTime,
                              alwaysUse24HourFormat: false,
                            ),
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: NeoColors.accentInk,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            countdownText,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: NeoColors.accentInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    NeoSquareIconButton(
                      icon: Icons.close,
                      backgroundColor: NeoColors.panel,
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: NeoPanel(
                    color: NeoColors.panel,
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TimeWheel(
                            controller: _hourController,
                            childCount: 12,
                            onSelectedItemChanged: (index) {
                              setState(() {
                                _selectedHour = index + 1;
                              });
                            },
                            itemBuilder: (context, index) => _TimeWheelValue(
                              label: '${index + 1}',
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            ':',
                            style: theme.textTheme.displayMedium?.copyWith(
                              color: NeoColors.ink,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _TimeWheel(
                            controller: _minuteController,
                            childCount: 60,
                            onSelectedItemChanged: (index) {
                              setState(() {
                                _selectedMinute = index;
                              });
                            },
                            itemBuilder: (context, index) => _TimeWheelValue(
                              label: index.toString().padLeft(2, '0'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 112,
                          child: _TimeWheel(
                            controller: _periodController,
                            childCount: 2,
                            onSelectedItemChanged: (index) {
                              setState(() {
                                _selectedPeriod = index == 0
                                    ? DayPeriod.am
                                    : DayPeriod.pm;
                              });
                            },
                            itemBuilder: (context, index) => _TimeWheelValue(
                              label: index == 0 ? 'AM' : 'PM',
                              compact: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: NeoActionButton(
                        label: 'Cancel',
                        backgroundColor: NeoColors.panel,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeoActionButton(
                        label: 'Apply',
                        backgroundColor: NeoColors.primary,
                        onPressed: () {
                          Navigator.of(context).pop(selectedTime);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TimeOfDay get _selectedTime {
    final normalizedHour = _selectedHour % 12;
    final resolvedHour = _selectedPeriod == DayPeriod.am
        ? normalizedHour
        : normalizedHour + 12;
    return TimeOfDay(hour: resolvedHour, minute: _selectedMinute);
  }
}

class _TimeWheel extends StatelessWidget {
  const _TimeWheel({
    required this.controller,
    required this.childCount,
    required this.itemBuilder,
    required this.onSelectedItemChanged,
  });

  final FixedExtentScrollController controller;
  final int childCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final ValueChanged<int> onSelectedItemChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CupertinoTheme(
          data: CupertinoThemeData(
            brightness: Theme.of(context).brightness,
            primaryColor: NeoColors.ink,
          ),
          child: CupertinoPicker.builder(
            scrollController: controller,
            itemExtent: 58,
            diameterRatio: 1.18,
            squeeze: 1.18,
            selectionOverlay: const SizedBox.shrink(),
            onSelectedItemChanged: onSelectedItemChanged,
            childCount: childCount,
            itemBuilder: itemBuilder,
          ),
        ),
        IgnorePointer(
          child: Container(
            height: 70,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: NeoColors.primary.withValues(alpha: 0.24),
              border: Border(
                top: BorderSide(color: NeoColors.ink, width: 3),
                bottom: BorderSide(color: NeoColors.ink, width: 3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeWheelValue extends StatelessWidget {
  const _TimeWheelValue({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Text(
        label,
        style: (compact
                ? theme.textTheme.headlineLarge
                : theme.textTheme.displayMedium)
            ?.copyWith(
              color: NeoColors.ink,
              fontStyle: FontStyle.italic,
              fontSize: compact ? 30 : 40,
            ),
      ),
    );
  }
}

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

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.label});

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

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.label, required this.active});

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

class _EditorSelector extends StatelessWidget {
  const _EditorSelector({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NeoPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          child,
        ],
      ),
    );
  }
}

class _EditorToggleRow extends StatelessWidget {
  const _EditorToggleRow({
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
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

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count, required this.selected, this.onTap});

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

class _EditorWarning extends StatelessWidget {
  const _EditorWarning({required this.title, required this.detail});

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
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
