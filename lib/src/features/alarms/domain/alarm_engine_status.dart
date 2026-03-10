class AlarmEngineStatus {
  const AlarmEngineStatus({
    required this.canScheduleExactAlarms,
    required this.notificationsEnabled,
    required this.timezoneId,
  });

  factory AlarmEngineStatus.fromMap(Map<Object?, Object?> raw) {
    return AlarmEngineStatus(
      canScheduleExactAlarms: raw['canScheduleExactAlarms']! as bool,
      notificationsEnabled: raw['notificationsEnabled']! as bool,
      timezoneId: raw['timezoneId']! as String,
    );
  }

  final bool canScheduleExactAlarms;
  final bool notificationsEnabled;
  final String timezoneId;
}
