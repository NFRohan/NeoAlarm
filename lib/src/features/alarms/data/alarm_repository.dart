import 'package:neoalarm/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_spec.dart';
import 'package:neoalarm/src/features/alarms/domain/active_alarm_session.dart';
import 'package:neoalarm/src/features/app_startup/domain/app_startup_context.dart';

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

  Future<AppStartupContext> getStartupContext();

  Future<ActiveAlarmSession?> getActiveAlarmSession();

  Stream<ActiveAlarmSession?> watchActiveAlarmSession();

  Future<void> dismissActiveAlarmSession();

  Future<void> snoozeActiveAlarmSession();

  Future<void> startMission();

  Future<void> registerMissionActivity();

  Future<MathAnswerSubmissionResult> submitMathAnswer(String answer);

  Future<void> requestBatteryOptimizationExemption();

  Future<void> requestCameraPermission();

  Future<void> requestActivityRecognitionPermission();

  Future<void> requestExactAlarmPermission();

  Future<void> requestNotificationPermission();
}
