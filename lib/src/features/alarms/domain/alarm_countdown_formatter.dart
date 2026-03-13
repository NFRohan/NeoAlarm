import 'package:neoalarm/src/features/alarms/domain/alarm_spec.dart';

DateTime computeNextAlarmPreview({
  required int hour,
  required int minute,
  required Iterable<AlarmWeekday> weekdays,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final normalizedReference = reference.copyWith(second: 0, millisecond: 0, microsecond: 0);

  if (weekdays.isEmpty) {
    var candidate = DateTime(
      normalizedReference.year,
      normalizedReference.month,
      normalizedReference.day,
      hour,
      minute,
    );
    if (!candidate.isAfter(normalizedReference)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  final weekdayValues = weekdays.map((weekday) => weekday.isoValue).toSet();
  for (var offset = 0; offset <= 7; offset++) {
    final date = normalizedReference.add(Duration(days: offset));
    if (!weekdayValues.contains(date.weekday)) {
      continue;
    }

    final candidate = DateTime(date.year, date.month, date.day, hour, minute);
    if (candidate.isAfter(normalizedReference)) {
      return candidate;
    }
  }

  return DateTime(
    normalizedReference.year,
    normalizedReference.month,
    normalizedReference.day,
    hour,
    minute,
  ).add(const Duration(days: 7));
}

String formatAlarmCountdown(
  DateTime target, {
  DateTime? now,
  String prefix = 'Alarm in',
}) {
  final reference = now ?? DateTime.now();
  final difference = target.difference(reference);
  final totalMinutes = difference.inMinutes;

  if (totalMinutes <= 0) {
    return '$prefix less than a minute';
  }

  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  final parts = <String>[];

  if (hours > 0) {
    parts.add('$hours ${hours == 1 ? 'hour' : 'hours'}');
  }
  if (minutes > 0) {
    parts.add('$minutes ${minutes == 1 ? 'minute' : 'minutes'}');
  }

  return '$prefix ${parts.join(' and ')}';
}
