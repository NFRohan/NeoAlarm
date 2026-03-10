class ActiveAlarmSession {
  const ActiveAlarmSession({
    required this.sessionId,
    required this.alarmId,
    required this.alarmLabel,
    required this.hour,
    required this.minute,
    required this.missionType,
    required this.startedAtUtc,
    required this.snoozeCount,
    required this.maxSnoozes,
  });

  factory ActiveAlarmSession.fromMap(Map<Object?, Object?> raw) {
    return ActiveAlarmSession(
      sessionId: raw['sessionId']! as String,
      alarmId: raw['alarmId']! as String,
      alarmLabel: raw['alarmLabel']! as String,
      hour: (raw['hour']! as num).toInt(),
      minute: (raw['minute']! as num).toInt(),
      missionType: raw['missionType']! as String,
      startedAtUtc: DateTime.parse(raw['startedAtUtc']! as String).toUtc(),
      snoozeCount: (raw['snoozeCount']! as num).toInt(),
      maxSnoozes: (raw['maxSnoozes']! as num).toInt(),
    );
  }

  final String sessionId;
  final String alarmId;
  final String alarmLabel;
  final int hour;
  final int minute;
  final String missionType;
  final DateTime startedAtUtc;
  final int snoozeCount;
  final int maxSnoozes;

  DateTime get startedAtLocal => startedAtUtc.toLocal();
}
