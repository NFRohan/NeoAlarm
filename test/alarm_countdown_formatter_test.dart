import 'package:neoalarm/src/features/alarms/domain/alarm_countdown_formatter.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_spec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('computes next one-time alarm for later today', () {
    final nextTrigger = computeNextAlarmPreview(
      hour: 9,
      minute: 45,
      weekdays: const [],
      now: DateTime(2026, 3, 14, 8, 15),
    );

    expect(nextTrigger, DateTime(2026, 3, 14, 9, 45));
    expect(
      formatAlarmCountdown(nextTrigger, now: DateTime(2026, 3, 14, 8, 15)),
      'Alarm in 1 hour and 30 minutes',
    );
  });

  test('computes next repeating alarm on the next matching weekday', () {
    final nextTrigger = computeNextAlarmPreview(
      hour: 7,
      minute: 30,
      weekdays: const [AlarmWeekday.monday, AlarmWeekday.friday],
      now: DateTime(2026, 3, 14, 22, 0),
    );

    expect(nextTrigger, DateTime(2026, 3, 16, 7, 30));
  });

  test('uses less than a minute wording for very short countdowns', () {
    final target = DateTime(2026, 3, 14, 10, 0, 30);

    expect(
      formatAlarmCountdown(target, now: DateTime(2026, 3, 14, 10, 0, 0)),
      'Alarm in less than a minute',
    );
  });
}
