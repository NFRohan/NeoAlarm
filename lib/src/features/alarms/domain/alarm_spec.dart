import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';

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

enum AlarmRingtone {
  systemAlarm('system_alarm', 'System alarm', 'Uses the device alarm sound.'),
  systemNotification(
    'system_notification',
    'Notification tone',
    'Uses the device notification sound.',
  );

  const AlarmRingtone(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static AlarmRingtone fromId(String? value) {
    return AlarmRingtone.values.firstWhere(
      (ringtone) => ringtone.id == value,
      orElse: () => AlarmRingtone.systemAlarm,
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
    required this.ringtone,
    required this.volumeRampEnabled,
    required this.extraLoudEnabled,
    required this.snoozeDurationMinutes,
    required this.maxSnoozes,
    required this.mission,
    required this.nextTriggerAtUtc,
    required this.skippedOccurrenceLocalDate,
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
      ringtone: AlarmRingtone.systemAlarm,
      volumeRampEnabled: false,
      extraLoudEnabled: false,
      snoozeDurationMinutes: 9,
      maxSnoozes: 3,
      mission: const MissionSpec.none(),
      nextTriggerAtUtc: null,
      skippedOccurrenceLocalDate: null,
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
      ringtone: AlarmRingtone.fromId(raw['ringtoneId'] as String?),
      volumeRampEnabled: raw['volumeRampEnabled'] as bool? ?? false,
      extraLoudEnabled: raw['extraLoudEnabled'] as bool? ?? false,
      snoozeDurationMinutes: (raw['snoozeDurationMinutes'] as num).toInt(),
      maxSnoozes: (raw['maxSnoozes'] as num).toInt(),
      mission: MissionSpec.fromMap(
        raw['mission'] as Map<Object?, Object?>?,
        fallbackType: raw['missionType'] as String?,
      ),
      nextTriggerAtUtc: nextTriggerValue == null
          ? null
          : DateTime.parse(nextTriggerValue as String).toUtc(),
      skippedOccurrenceLocalDate: raw['skippedOccurrenceLocalDate'] as String?,
    );
  }

  final String id;
  final String label;
  final int hour;
  final int minute;
  final String timezoneId;
  final bool enabled;
  final List<AlarmWeekday> weekdays;
  final AlarmRingtone ringtone;
  final bool volumeRampEnabled;
  final bool extraLoudEnabled;
  final int snoozeDurationMinutes;
  final int maxSnoozes;
  final MissionSpec mission;
  final DateTime? nextTriggerAtUtc;
  final String? skippedOccurrenceLocalDate;

  DateTime? get nextTriggerAtLocal => nextTriggerAtUtc?.toLocal();

  bool get repeats => weekdays.isNotEmpty;

  String get repeatSummary {
    if (weekdays.isEmpty) {
      return 'One time';
    }

    return weekdays.map((weekday) => weekday.shortLabel).join(' ');
  }

  String get ringtoneSummary => ringtone.label;

  String get missionSummary => mission.summary;

  String get volumeSummary {
    final labels = <String>[
      if (volumeRampEnabled) 'Ramp up' else 'Full volume',
      if (extraLoudEnabled) 'Extra loud',
    ];
    return labels.join(' · ');
  }

  bool get hasSkippedOccurrence => skippedOccurrenceLocalDate != null;

  AlarmSpec copyWith({
    String? id,
    String? label,
    int? hour,
    int? minute,
    String? timezoneId,
    bool? enabled,
    List<AlarmWeekday>? weekdays,
    AlarmRingtone? ringtone,
    bool? volumeRampEnabled,
    bool? extraLoudEnabled,
    int? snoozeDurationMinutes,
    int? maxSnoozes,
    MissionSpec? mission,
    DateTime? nextTriggerAtUtc,
    String? skippedOccurrenceLocalDate,
    bool clearSkippedOccurrenceLocalDate = false,
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
      ringtone: ringtone ?? this.ringtone,
      volumeRampEnabled: volumeRampEnabled ?? this.volumeRampEnabled,
      extraLoudEnabled: extraLoudEnabled ?? this.extraLoudEnabled,
      snoozeDurationMinutes:
          snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      maxSnoozes: maxSnoozes ?? this.maxSnoozes,
      mission: mission ?? this.mission,
      nextTriggerAtUtc: clearNextTriggerAtUtc
          ? null
          : nextTriggerAtUtc ?? this.nextTriggerAtUtc,
      skippedOccurrenceLocalDate: clearSkippedOccurrenceLocalDate
          ? null
          : skippedOccurrenceLocalDate ?? this.skippedOccurrenceLocalDate,
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
      'ringtoneId': ringtone.id,
      'volumeRampEnabled': volumeRampEnabled,
      'extraLoudEnabled': extraLoudEnabled,
      'snoozeDurationMinutes': snoozeDurationMinutes,
      'maxSnoozes': maxSnoozes,
      'mission': mission.toMap(),
      'nextTriggerAtUtc': nextTriggerAtUtc?.toIso8601String(),
      'skippedOccurrenceLocalDate': skippedOccurrenceLocalDate,
    };
  }
}
