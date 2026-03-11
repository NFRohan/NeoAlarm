import 'package:alarms_oss/src/core/theme/app_theme.dart';
import 'package:alarms_oss/src/core/ui/neo_brutal_widgets.dart';
import 'package:alarms_oss/src/features/alarms/domain/alarm_mission.dart';
import 'package:alarms_oss/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:alarms_oss/src/features/alarms/domain/alarm_spec.dart';
import 'package:flutter/material.dart';

class AlarmEditorSheet extends StatefulWidget {
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
  State<AlarmEditorSheet> createState() => _AlarmEditorSheetState();
}

class _AlarmEditorSheetState extends State<AlarmEditorSheet> {
  late final TextEditingController _labelController;
  late TimeOfDay _time;
  late bool _enabled;
  late Set<AlarmWeekday> _selectedWeekdays;
  late AlarmRingtone _ringtone;
  late int _snoozeDurationMinutes;
  late int _maxSnoozes;
  late MissionSpec _mission;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.alarm.label);
    _time = TimeOfDay(hour: widget.alarm.hour, minute: widget.alarm.minute);
    _enabled = widget.alarm.enabled;
    _selectedWeekdays = widget.alarm.weekdays.toSet();
    _ringtone = widget.alarm.ringtone;
    _snoozeDurationMinutes = widget.alarm.snoozeDurationMinutes;
    _maxSnoozes = widget.alarm.maxSnoozes;
    _mission =
        _missionOptionFor(
          widget.alarm.mission.type,
          widget.engineStatus,
        ).enabled
        ? widget.alarm.mission
        : const MissionSpec.none();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final diagnostics = widget.engineStatus;
    final amPmLabel = _time.period == DayPeriod.am ? 'AM' : 'PM';

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
                decoration: const BoxDecoration(
                  color: Color(0x22FFFF00),
                  border: Border(
                    top: BorderSide(color: NeoColors.ink, width: 3),
                    bottom: BorderSide(color: NeoColors.ink, width: 3),
                  ),
                ),
                child: InkWell(
                  onTap: _pickTime,
                  child: Row(
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
                          items: AlarmMissionType.values
                              .map((missionType) {
                                final option = _missionOptionFor(
                                  missionType,
                                  diagnostics,
                                );
                                return DropdownMenuItem<AlarmMissionType>(
                                  value: missionType,
                                  enabled: option.enabled,
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
    final selected = await showTimePicker(context: context, initialTime: _time);

    if (selected == null) {
      return;
    }

    setState(() {
      _time = selected;
    });
  }

  void _save() {
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
            'Solve a generated math problem to dismiss the alarm. Difficulty is configurable below.',
        enabled: true,
      ),
      AlarmMissionType.steps => _MissionOption(
        title: 'Steps mission',
        detail: !((diagnostics?.hasStepSensor) ?? false)
            ? 'This device does not expose a hardware step counter.'
            : !((diagnostics?.activityRecognitionGranted) ?? false)
            ? 'Grant activity recognition from diagnostics before this mission can be enabled later.'
            : 'Sensor prerequisites look good. Mission runtime lands in Sprint 6.',
        enabled: false,
      ),
      AlarmMissionType.qr => _MissionOption(
        title: 'QR mission',
        detail: !((diagnostics?.hasCamera) ?? false)
            ? 'This device does not report camera availability.'
            : !((diagnostics?.cameraPermissionGranted) ?? false)
            ? 'Grant camera permission from diagnostics before this mission can be enabled later.'
            : 'Camera prerequisites look good. Native vision runtime lands in Sprint 7.',
        enabled: false,
      ),
    };
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
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: active ? NeoColors.primary : NeoColors.panel,
        border: Border.all(color: NeoColors.ink, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: NeoColors.ink),
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

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count, required this.selected, this.onTap});

  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected ? NeoColors.primary : NeoColors.panel,
          border: Border.all(color: NeoColors.ink, width: 2),
        ),
        alignment: Alignment.center,
        child: Text('$count', style: Theme.of(context).textTheme.titleMedium),
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
        color: const Color(0xFFFFF2EE),
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
                color: const Color(0xFF56483A),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
