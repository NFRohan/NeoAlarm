import 'package:alarms_oss/src/features/alarms/domain/alarm_spec.dart';
import 'package:alarms_oss/src/features/alarms/domain/alarm_mission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes and deserializes alarm specs', () {
    final original = AlarmSpec(
      id: 'alarm-1',
      label: 'Morning',
      hour: 7,
      minute: 30,
      timezoneId: 'Asia/Dhaka',
      enabled: true,
      weekdays: const [
        AlarmWeekday.monday,
        AlarmWeekday.wednesday,
        AlarmWeekday.friday,
      ],
      ringtone: AlarmRingtone.systemNotification,
      snoozeDurationMinutes: 9,
      maxSnoozes: 3,
      mission: const MissionSpec.math(difficulty: MathMissionDifficulty.hard),
      nextTriggerAtUtc: DateTime.utc(2026, 3, 12, 1, 30),
    );

    final roundTrip = AlarmSpec.fromMap(original.toMap());

    expect(roundTrip.id, original.id);
    expect(roundTrip.label, original.label);
    expect(roundTrip.hour, original.hour);
    expect(roundTrip.minute, original.minute);
    expect(roundTrip.timezoneId, original.timezoneId);
    expect(roundTrip.enabled, isTrue);
    expect(roundTrip.weekdays, original.weekdays);
    expect(roundTrip.ringtone, original.ringtone);
    expect(roundTrip.mission.type, original.mission.type);
    expect(roundTrip.mission.mathDifficulty, original.mission.mathDifficulty);
    expect(roundTrip.nextTriggerAtUtc, original.nextTriggerAtUtc);
  });

  test('uses one-time summary when no weekdays are selected', () {
    final alarm = AlarmSpec.createDraft(timezoneId: 'UTC');

    expect(alarm.repeatSummary, 'One time');
  });
}
