import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoalarm/src/features/alarms/application/alarm_list_controller.dart';
import 'package:neoalarm/src/features/alarms/data/alarm_repository.dart';
import 'package:neoalarm/src/features/alarms/domain/active_alarm_session.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_location_trigger.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_spec.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_tone.dart';
import 'package:neoalarm/src/features/app_startup/domain/app_startup_context.dart';
import 'package:neoalarm/src/features/location_alarms/domain/current_location_snapshot.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_alarm_setup_diagnostics.dart';

void main() {
  test('setEnabled preserves alarm position in the dashboard list', () async {
    final first = AlarmSpec(
      id: 'first',
      label: 'First',
      hour: 7,
      minute: 0,
      timezoneId: 'UTC',
      enabled: true,
      weekdays: const [],
      ringtone: AlarmRingtone.systemAlarm,
      customToneId: null,
      customToneName: null,
      customToneHealthy: true,
      volumeRampEnabled: false,
      extraLoudEnabled: false,
      snoozeDurationMinutes: 5,
      maxSnoozes: 3,
      mission: const MissionSpec.none(),
      nextTriggerAtUtc: DateTime.utc(2026, 5, 17, 1, 0),
      skippedOccurrenceLocalDate: null,
    );
    final second = AlarmSpec(
      id: 'second',
      label: 'Second',
      hour: 8,
      minute: 0,
      timezoneId: 'UTC',
      enabled: true,
      weekdays: const [],
      ringtone: AlarmRingtone.systemAlarm,
      customToneId: null,
      customToneName: null,
      customToneHealthy: true,
      volumeRampEnabled: false,
      extraLoudEnabled: false,
      snoozeDurationMinutes: 5,
      maxSnoozes: 3,
      mission: const MissionSpec.none(),
      nextTriggerAtUtc: DateTime.utc(2026, 5, 16, 1, 0),
      skippedOccurrenceLocalDate: null,
    );

    final repository = _FakeAlarmRepository([first, second]);
    final container = ProviderContainer(
      overrides: [alarmRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(alarmListControllerProvider.future);
    await container
        .read(alarmListControllerProvider.notifier)
        .setEnabled(id: 'first', enabled: false);

    final alarms = container.read(alarmListControllerProvider).requireValue;
    expect(alarms.map((alarm) => alarm.id).toList(), ['first', 'second']);
    expect(alarms.first.enabled, isFalse);
  });
}

class _FakeAlarmRepository implements AlarmRepository {
  _FakeAlarmRepository(this.alarms);

  final List<AlarmSpec> alarms;

  @override
  Future<List<AlarmSpec>> listAlarms() async => List<AlarmSpec>.from(alarms);

  @override
  Future<AlarmSpec> setAlarmEnabled({
    required String id,
    required bool enabled,
  }) async {
    final index = alarms.indexWhere((alarm) => alarm.id == id);
    final updated = alarms[index].copyWith(enabled: enabled);
    alarms[index] = updated;
    return updated;
  }

  @override
  Future<AlarmSpec> upsertAlarm(AlarmSpec alarm) async => alarm;

  @override
  Future<void> deleteAlarm(String id) async {}

  @override
  Future<AlarmSpec> skipNextOccurrence(String id) {
    throw UnimplementedError();
  }

  @override
  Future<AlarmSpec> clearSkippedOccurrence(String id) {
    throw UnimplementedError();
  }

  @override
  Future<AlarmSpec> refreshLocationAlarm(String id) async {
    final index = alarms.indexWhere((alarm) => alarm.id == id);
    return alarms[index];
  }

  @override
  Future<void> refreshLocationAlarms() async {}

  @override
  Future<List<String>> listAvailableTimezones() async => const ['UTC'];

  @override
  Future<List<AlarmTone>> listCustomTones() async => const [];

  @override
  Future<AlarmTone?> importCustomTone() async => null;

  @override
  Future<List<String>> deleteCustomTone(String id) async => const [];

  @override
  Future<void> rescheduleAll() async {}

  @override
  Future<AlarmEngineStatus> getStatus() async => const AlarmEngineStatus(
    canScheduleExactAlarms: true,
    notificationsEnabled: true,
    batteryOptimizationIgnored: true,
    hasCamera: true,
    cameraPermissionGranted: true,
    hasStepSensor: true,
    activityRecognitionGranted: true,
    timezoneId: 'UTC',
    locationServicesEnabled: true,
    foregroundLocationGranted: true,
    backgroundLocationGranted: true,
  );

  @override
  Future<AppStartupContext> getStartupContext() async =>
      const AppStartupContext(userUnlocked: true);

  @override
  Future<ActiveAlarmSession?> getActiveAlarmSession() async => null;

  @override
  Stream<ActiveAlarmSession?> watchActiveAlarmSession() => const Stream.empty();

  @override
  Future<void> dismissActiveAlarmSession() async {}

  @override
  Future<void> snoozeActiveAlarmSession() async {}

  @override
  Future<void> startMission() async {}

  @override
  Future<void> registerMissionActivity() async {}

  @override
  Future<MathAnswerSubmissionResult> submitMathAnswer(String answer) async =>
      MathAnswerSubmissionResult.incorrect;

  @override
  Future<void> requestBatteryOptimizationExemption() async {}

  @override
  Future<void> requestCameraPermission() async {}

  @override
  Future<void> requestActivityRecognitionPermission() async {}

  @override
  Future<void> requestForegroundLocationPermission() async {}

  @override
  Future<void> requestBackgroundLocationPermission() async {}

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<CurrentLocationSnapshot?> getCurrentLocationSnapshot() async => null;

  @override
  Future<LocationAlarmSetupDiagnostics> evaluateLocationTrigger(
    AlarmLocationTrigger trigger,
  ) async => const LocationAlarmSetupDiagnostics(
    health: AlarmLocationHealth.healthy,
    alreadyInsideRadius: false,
  );

  @override
  Future<void> runLocationAlarmForegroundCheck() async {}

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<void> requestNotificationPermission() async {}
}
