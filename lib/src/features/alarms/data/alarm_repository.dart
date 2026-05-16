import 'package:neoalarm/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_location_trigger.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_spec.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_tone.dart';
import 'package:neoalarm/src/features/alarms/domain/active_alarm_session.dart';
import 'package:neoalarm/src/features/app_startup/domain/app_startup_context.dart';
import 'package:neoalarm/src/features/location_alarms/domain/current_location_snapshot.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_alarm_setup_diagnostics.dart';

abstract class AlarmRepository {
  Future<List<AlarmSpec>> listAlarms();

  Future<AlarmSpec> upsertAlarm(AlarmSpec alarm);

  Future<void> deleteAlarm(String id);

  Future<AlarmSpec> setAlarmEnabled({
    required String id,
    required bool enabled,
  });

  Future<AlarmSpec> skipNextOccurrence(String id);

  Future<AlarmSpec> clearSkippedOccurrence(String id);

  Future<List<String>> listAvailableTimezones();

  Future<AlarmSpec> refreshLocationAlarm(String id);

  Future<void> refreshLocationAlarms();

  Future<List<AlarmTone>> listCustomTones();

  Future<AlarmTone?> importCustomTone();

  Future<List<String>> deleteCustomTone(String id);

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

  Future<void> requestForegroundLocationPermission();

  Future<void> requestBackgroundLocationPermission();

  Future<void> openLocationSettings();

  Future<CurrentLocationSnapshot?> getCurrentLocationSnapshot();

  Future<LocationAlarmSetupDiagnostics> evaluateLocationTrigger(
    AlarmLocationTrigger trigger,
  );

  Future<void> runLocationAlarmForegroundCheck();

  Future<void> requestExactAlarmPermission();

  Future<void> requestNotificationPermission();
}
