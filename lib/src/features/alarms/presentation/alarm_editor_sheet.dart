import 'package:alarms_oss/src/features/alarms/domain/alarm_spec.dart';
import 'package:flutter/material.dart';

class AlarmEditorSheet extends StatefulWidget {
  const AlarmEditorSheet({required this.alarm, super.key});

  final AlarmSpec alarm;

  static Future<AlarmSpec?> show(
    BuildContext context, {
    required AlarmSpec alarm,
  }) {
    return showModalBottomSheet<AlarmSpec>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => AlarmEditorSheet(alarm: alarm),
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

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.alarm.label);
    _time = TimeOfDay(hour: widget.alarm.hour, minute: widget.alarm.minute);
    _enabled = widget.alarm.enabled;
    _selectedWeekdays = widget.alarm.weekdays.toSet();
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

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + mediaQuery.viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alarm details',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sprint 2 keeps the editor focused on scheduling and exact-alarm persistence.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF56483A),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: _pickTime,
            child: Text('Time: ${_time.format(context)}'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Repeat days',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AlarmWeekday.values
                .map((weekday) {
                  return FilterChip(
                    label: Text(weekday.shortLabel),
                    selected: _selectedWeekdays.contains(weekday),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedWeekdays.add(weekday);
                        } else {
                          _selectedWeekdays.remove(weekday);
                        }
                      });
                    },
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            value: _enabled,
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            subtitle: const Text(
              'Disabled alarms stay persisted but unscheduled.',
            ),
            onChanged: (value) {
              setState(() {
                _enabled = value;
              });
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save alarm'),
            ),
          ),
        ],
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
        clearNextTriggerAtUtc: true,
      ),
    );
  }
}
