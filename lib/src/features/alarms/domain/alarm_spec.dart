enum AlarmWeekday {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  int get isoValue => index + 1;

  String get shortLabel => switch (this) {
    AlarmWeekday.monday => 'Mon',
    AlarmWeekday.tuesday => 'Tue',
    AlarmWeekday.wednesday => 'Wed',
    AlarmWeekday.thursday => 'Thu',
    AlarmWeekday.friday => 'Fri',
    AlarmWeekday.saturday => 'Sat',
    AlarmWeekday.sunday => 'Sun',
  };

  static AlarmWeekday fromIsoValue(int value) {
    return AlarmWeekday.values.firstWhere(
      (weekday) => weekday.isoValue == value,
      orElse: () => AlarmWeekday.monday,
    );
  }
}

class AlarmSpec {
  const AlarmSpec({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    required this.timezoneId,
    required this.enabled,
    required this.weekdays,
    required this.snoozeDurationMinutes,
    required this.maxSnoozes,
    required this.missionType,
    required this.nextTriggerAtUtc,
  });

  factory AlarmSpec.createDraft({required String timezoneId, DateTime? now}) {
    final reference = (now ?? DateTime.now()).add(const Duration(minutes: 2));

    return AlarmSpec(
      id: reference.microsecondsSinceEpoch.toString(),
      label: 'Alarm',
      hour: reference.hour,
      minute: reference.minute,
      timezoneId: timezoneId,
      enabled: true,
      weekdays: const [],
      snoozeDurationMinutes: 9,
      maxSnoozes: 3,
      missionType: 'none',
      nextTriggerAtUtc: null,
    );
  }

  factory AlarmSpec.fromMap(Map<Object?, Object?> raw) {
    final weekdaysRaw =
        (raw['weekdays'] as List<Object?>? ?? const [])
            .map((value) => AlarmWeekday.fromIsoValue((value as num).toInt()))
            .toList()
          ..sort((left, right) => left.isoValue.compareTo(right.isoValue));

    final nextTriggerValue = raw['nextTriggerAtUtc'];

    return AlarmSpec(
      id: raw['id']! as String,
      label: (raw['label'] as String?)?.trim().isNotEmpty == true
          ? raw['label']! as String
          : 'Alarm',
      hour: (raw['hour'] as num).toInt(),
      minute: (raw['minute'] as num).toInt(),
      timezoneId: raw['timezoneId']! as String,
      enabled: raw['enabled']! as bool,
      weekdays: weekdaysRaw,
      snoozeDurationMinutes: (raw['snoozeDurationMinutes'] as num).toInt(),
      maxSnoozes: (raw['maxSnoozes'] as num).toInt(),
      missionType: raw['missionType']! as String,
      nextTriggerAtUtc: nextTriggerValue == null
          ? null
          : DateTime.parse(nextTriggerValue as String).toUtc(),
    );
  }

  final String id;
  final String label;
  final int hour;
  final int minute;
  final String timezoneId;
  final bool enabled;
  final List<AlarmWeekday> weekdays;
  final int snoozeDurationMinutes;
  final int maxSnoozes;
  final String missionType;
  final DateTime? nextTriggerAtUtc;

  DateTime? get nextTriggerAtLocal => nextTriggerAtUtc?.toLocal();

  bool get repeats => weekdays.isNotEmpty;

  String get repeatSummary {
    if (weekdays.isEmpty) {
      return 'One time';
    }

    return weekdays.map((weekday) => weekday.shortLabel).join(' ');
  }

  AlarmSpec copyWith({
    String? id,
    String? label,
    int? hour,
    int? minute,
    String? timezoneId,
    bool? enabled,
    List<AlarmWeekday>? weekdays,
    int? snoozeDurationMinutes,
    int? maxSnoozes,
    String? missionType,
    DateTime? nextTriggerAtUtc,
    bool clearNextTriggerAtUtc = false,
  }) {
    final normalizedWeekdays = [...?weekdays]
      ..sort((left, right) => left.isoValue.compareTo(right.isoValue));

    return AlarmSpec(
      id: id ?? this.id,
      label: label ?? this.label,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      timezoneId: timezoneId ?? this.timezoneId,
      enabled: enabled ?? this.enabled,
      weekdays: weekdays == null ? this.weekdays : normalizedWeekdays,
      snoozeDurationMinutes:
          snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      maxSnoozes: maxSnoozes ?? this.maxSnoozes,
      missionType: missionType ?? this.missionType,
      nextTriggerAtUtc: clearNextTriggerAtUtc
          ? null
          : nextTriggerAtUtc ?? this.nextTriggerAtUtc,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'label': label,
      'hour': hour,
      'minute': minute,
      'timezoneId': timezoneId,
      'enabled': enabled,
      'weekdays': weekdays.map((weekday) => weekday.isoValue).toList(),
      'snoozeDurationMinutes': snoozeDurationMinutes,
      'maxSnoozes': maxSnoozes,
      'missionType': missionType,
      'nextTriggerAtUtc': nextTriggerAtUtc?.toIso8601String(),
    };
  }
}
