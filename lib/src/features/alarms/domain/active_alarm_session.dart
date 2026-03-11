import 'package:alarms_oss/src/features/alarms/domain/alarm_mission.dart';

class ActiveAlarmSession {
  const ActiveAlarmSession({
    required this.sessionId,
    required this.alarmId,
    required this.alarmLabel,
    required this.hour,
    required this.minute,
    required this.state,
    required this.mission,
    required this.startedAtUtc,
    required this.snoozeCount,
    required this.maxSnoozes,
    required this.snoozeDurationMinutes,
  });

  factory ActiveAlarmSession.fromMap(Map<Object?, Object?> raw) {
    return ActiveAlarmSession(
      sessionId: raw['sessionId']! as String,
      alarmId: raw['alarmId']! as String,
      alarmLabel: raw['alarmLabel']! as String,
      hour: (raw['hour']! as num).toInt(),
      minute: (raw['minute']! as num).toInt(),
      state: ActiveAlarmSessionState.fromId(raw['state'] as String?),
      mission: ActiveMissionSnapshot.fromMap(
        raw['mission'] as Map<Object?, Object?>? ??
            <Object?, Object?>{'type': raw['missionType'] as String? ?? 'none'},
      ),
      startedAtUtc: DateTime.parse(raw['startedAtUtc']! as String).toUtc(),
      snoozeCount: (raw['snoozeCount']! as num).toInt(),
      maxSnoozes: (raw['maxSnoozes']! as num).toInt(),
      snoozeDurationMinutes: (raw['snoozeDurationMinutes']! as num).toInt(),
    );
  }

  final String sessionId;
  final String alarmId;
  final String alarmLabel;
  final int hour;
  final int minute;
  final ActiveAlarmSessionState state;
  final ActiveMissionSnapshot mission;
  final DateTime startedAtUtc;
  final int snoozeCount;
  final int maxSnoozes;
  final int snoozeDurationMinutes;

  DateTime get startedAtLocal => startedAtUtc.toLocal();

  bool get canSnooze => snoozeCount < maxSnoozes;

  bool get requiresMission => !mission.spec.isDirectDismiss;
}
