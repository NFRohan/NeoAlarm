import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_location_trigger.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_timezone.dart';

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
  ),
  customTone(
    'custom_tone',
    'Custom tone',
    'Uses an imported custom alarm tone.',
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
    this.followsDeviceTimezone = true,
    required this.enabled,
    required this.weekdays,
    required this.ringtone,
    required this.customToneId,
    required this.customToneName,
    required this.customToneHealthy,
    required this.volumeRampEnabled,
    required this.extraLoudEnabled,
    required this.snoozeDurationMinutes,
    required this.maxSnoozes,
    required this.mission,
    required this.nextTriggerAtUtc,
    required this.skippedOccurrenceLocalDate,
    this.triggerKind = AlarmTriggerKind.time,
    this.locationTrigger,
  });

  factory AlarmSpec.createDraft({required String timezoneId, DateTime? now}) {
    final reference = (now ?? DateTime.now()).add(const Duration(minutes: 2));

    return AlarmSpec(
      id: reference.microsecondsSinceEpoch.toString(),
      label: 'Alarm',
      hour: reference.hour,
      minute: reference.minute,
      timezoneId: timezoneId,
      followsDeviceTimezone: true,
      enabled: true,
      weekdays: const [],
      ringtone: AlarmRingtone.systemAlarm,
      customToneId: null,
      customToneName: null,
      customToneHealthy: true,
      volumeRampEnabled: false,
      extraLoudEnabled: false,
      snoozeDurationMinutes: 9,
      maxSnoozes: 3,
      mission: const MissionSpec.none(),
      nextTriggerAtUtc: null,
      skippedOccurrenceLocalDate: null,
      triggerKind: AlarmTriggerKind.time,
      locationTrigger: null,
    );
  }

  factory AlarmSpec.createLocationDraft({
    required String timezoneId,
    required AlarmLocationTrigger locationTrigger,
  }) {
    final reference = DateTime.now();

    return AlarmSpec(
      id: reference.microsecondsSinceEpoch.toString(),
      label: locationTrigger.label,
      hour: 0,
      minute: 0,
      timezoneId: timezoneId,
      followsDeviceTimezone: true,
      enabled: true,
      weekdays: const [],
      ringtone: AlarmRingtone.systemAlarm,
      customToneId: null,
      customToneName: null,
      customToneHealthy: true,
      volumeRampEnabled: false,
      extraLoudEnabled: false,
      snoozeDurationMinutes: 9,
      maxSnoozes: 3,
      mission: const MissionSpec.none(),
      nextTriggerAtUtc: null,
      skippedOccurrenceLocalDate: null,
      triggerKind: AlarmTriggerKind.location,
      locationTrigger: locationTrigger,
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
      followsDeviceTimezone: raw['followsDeviceTimezone'] as bool? ?? true,
      enabled: raw['enabled']! as bool,
      weekdays: weekdaysRaw,
      ringtone: AlarmRingtone.fromId(raw['ringtoneId'] as String?),
      customToneId: raw['customToneId'] as String?,
      customToneName: raw['customToneName'] as String?,
      customToneHealthy: raw['customToneHealthy'] as bool? ?? true,
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
      triggerKind: AlarmTriggerKind.fromId(raw['triggerKind'] as String?),
      locationTrigger:
          (raw['locationTrigger'] as Map<Object?, Object?>?) != null
          ? AlarmLocationTrigger.fromMap(
              raw['locationTrigger'] as Map<Object?, Object?>,
            )
          : null,
    );
  }

  final String id;
  final String label;
  final int hour;
  final int minute;
  final String timezoneId;
  final bool followsDeviceTimezone;
  final bool enabled;
  final List<AlarmWeekday> weekdays;
  final AlarmRingtone ringtone;
  final String? customToneId;
  final String? customToneName;
  final bool customToneHealthy;
  final bool volumeRampEnabled;
  final bool extraLoudEnabled;
  final int snoozeDurationMinutes;
  final int maxSnoozes;
  final MissionSpec mission;
  final DateTime? nextTriggerAtUtc;
  final String? skippedOccurrenceLocalDate;
  final AlarmTriggerKind triggerKind;
  final AlarmLocationTrigger? locationTrigger;

  DateTime? get nextTriggerAtLocal => nextTriggerAtUtc?.toLocal();

  bool get isTimeAlarm => triggerKind == AlarmTriggerKind.time;

  bool get isLocationAlarm => triggerKind == AlarmTriggerKind.location;

  bool get usesSpecificTimezone => isTimeAlarm && !followsDeviceTimezone;

  String get timezoneSummary =>
      followsDeviceTimezone ? 'Device time' : formatTimezoneSummary(timezoneId);

  bool get repeats => weekdays.isNotEmpty;

  String get repeatSummary {
    if (isLocationAlarm) {
      return 'Location trigger';
    }

    if (weekdays.isEmpty) {
      return 'One time';
    }

    return weekdays.map((weekday) => weekday.shortLabel).join(' ');
  }

  String get ringtoneSummary {
    if (ringtone == AlarmRingtone.customTone) {
      return customToneName ?? 'Custom tone';
    }
    return ringtone.label;
  }

  String get missionSummary => mission.summary;

  String get triggerSummary {
    if (isLocationAlarm) {
      final location = locationTrigger;
      if (location == null) {
        return 'Location alarm';
      }
      return '${location.label} · ${location.radiusSummary}';
    }

    return repeatSummary;
  }

  String get volumeSummary {
    final labels = <String>[
      if (volumeRampEnabled) 'Ramp up' else 'Full volume',
      if (extraLoudEnabled) 'Extra loud',
    ];
    return labels.join(' | ');
  }

  bool get hasSkippedOccurrence =>
      isTimeAlarm && skippedOccurrenceLocalDate != null;

  bool get hasPendingSkippedOccurrence {
    if (!hasSkippedOccurrence) {
      return false;
    }

    final skippedDate = DateTime.tryParse(skippedOccurrenceLocalDate!);
    if (skippedDate == null) {
      return true;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final skippedLocalDate = DateTime(
      skippedDate.year,
      skippedDate.month,
      skippedDate.day,
    );

    return !today.isAfter(skippedLocalDate);
  }

  bool get hasCustomToneWarning =>
      ringtone == AlarmRingtone.customTone && !customToneHealthy;

  bool get hasLocationWarning =>
      isLocationAlarm && locationTrigger != null && !locationTrigger!.isHealthy;

  AlarmSpec copyWith({
    String? id,
    String? label,
    int? hour,
    int? minute,
    String? timezoneId,
    bool? followsDeviceTimezone,
    bool? enabled,
    List<AlarmWeekday>? weekdays,
    AlarmRingtone? ringtone,
    String? customToneId,
    String? customToneName,
    bool? customToneHealthy,
    bool clearCustomToneId = false,
    bool? volumeRampEnabled,
    bool? extraLoudEnabled,
    int? snoozeDurationMinutes,
    int? maxSnoozes,
    MissionSpec? mission,
    DateTime? nextTriggerAtUtc,
    String? skippedOccurrenceLocalDate,
    AlarmTriggerKind? triggerKind,
    AlarmLocationTrigger? locationTrigger,
    bool clearLocationTrigger = false,
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
      followsDeviceTimezone:
          followsDeviceTimezone ?? this.followsDeviceTimezone,
      enabled: enabled ?? this.enabled,
      weekdays: weekdays == null ? this.weekdays : normalizedWeekdays,
      ringtone: ringtone ?? this.ringtone,
      customToneId: clearCustomToneId
          ? null
          : customToneId ?? this.customToneId,
      customToneName: customToneName ?? this.customToneName,
      customToneHealthy: customToneHealthy ?? this.customToneHealthy,
      volumeRampEnabled: volumeRampEnabled ?? this.volumeRampEnabled,
      extraLoudEnabled: extraLoudEnabled ?? this.extraLoudEnabled,
      snoozeDurationMinutes:
          snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      maxSnoozes: maxSnoozes ?? this.maxSnoozes,
      mission: mission ?? this.mission,
      nextTriggerAtUtc: clearNextTriggerAtUtc
          ? null
          : nextTriggerAtUtc ?? this.nextTriggerAtUtc,
      triggerKind: triggerKind ?? this.triggerKind,
      locationTrigger: clearLocationTrigger
          ? null
          : locationTrigger ?? this.locationTrigger,
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
      'followsDeviceTimezone': followsDeviceTimezone,
      'enabled': enabled,
      'weekdays': weekdays.map((weekday) => weekday.isoValue).toList(),
      'ringtoneId': ringtone.id,
      'customToneId': customToneId,
      'volumeRampEnabled': volumeRampEnabled,
      'extraLoudEnabled': extraLoudEnabled,
      'snoozeDurationMinutes': snoozeDurationMinutes,
      'maxSnoozes': maxSnoozes,
      'mission': mission.toMap(),
      'nextTriggerAtUtc': nextTriggerAtUtc?.toIso8601String(),
      'triggerKind': triggerKind.id,
      'locationTrigger': locationTrigger?.toMap(),
      'skippedOccurrenceLocalDate': skippedOccurrenceLocalDate,
    };
  }
}
