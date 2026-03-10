import 'package:alarms_oss/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:alarms_oss/src/features/alarms/domain/alarm_spec.dart';
import 'package:alarms_oss/src/features/alarms/domain/active_alarm_session.dart';

abstract class AlarmRepository {
  Future<List<AlarmSpec>> listAlarms();

  Future<AlarmSpec> upsertAlarm(AlarmSpec alarm);

  Future<void> deleteAlarm(String id);

  Future<AlarmSpec> setAlarmEnabled({
    required String id,
    required bool enabled,
  });

  Future<void> rescheduleAll();

  Future<AlarmEngineStatus> getStatus();

  Future<ActiveAlarmSession?> getActiveAlarmSession();

  Future<void> dismissActiveAlarmSession();

  Future<void> requestExactAlarmPermission();

  Future<void> requestNotificationPermission();
}
