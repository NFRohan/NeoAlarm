import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neoalarm/src/features/alarms/data/alarm_repository.dart';
import 'package:neoalarm/src/features/alarms/application/alarm_list_controller.dart';
import 'package:neoalarm/src/features/alarms/domain/active_alarm_session.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_location_trigger.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_spec.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_tone.dart';
import 'package:neoalarm/src/features/app_startup/domain/app_startup_context.dart';
import 'package:neoalarm/src/features/location_alarms/domain/current_location_snapshot.dart';
import 'package:neoalarm/src/features/location_alarms/data/location_search_repository.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_alarm_setup_diagnostics.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_search_result.dart';
import 'package:neoalarm/src/features/location_alarms/presentation/location_alarm_setup_screen.dart';

void main() {
  testWidgets(
    'location setup keeps device readiness actions out of the setup flow',
    (tester) async {
      final repository = _FakeAlarmRepository(
        diagnostics: const LocationAlarmSetupDiagnostics(
          health: AlarmLocationHealth.noForegroundPermission,
          alreadyInsideRadius: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alarmRepositoryProvider.overrideWithValue(repository),
            locationSearchRepositoryProvider.overrideWithValue(
              const _FakeLocationSearchRepository(),
            ),
          ],
          child: const MaterialApp(
            home: LocationAlarmSetupScreen(
              initialTrigger: AlarmLocationTrigger(
                label: 'Banani Station',
                latitude: 23.7936,
                longitude: 90.4066,
                radiusMeters: 1000,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('GRANT LOCATION ACCESS'), findsNothing);
      expect(find.text('USE DESTINATION'), findsOneWidget);
      expect(repository.foregroundRequestCount, 0);
    },
  );

  testWidgets('location setup centers the map on the current device location', (
    tester,
  ) async {
    final repository = _FakeAlarmRepository(
      diagnostics: const LocationAlarmSetupDiagnostics(
        health: AlarmLocationHealth.healthy,
        alreadyInsideRadius: false,
      ),
      currentLocationSnapshot: const CurrentLocationSnapshot(
        latitude: 23.8103,
        longitude: 90.4125,
        accuracyMeters: 18,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmRepositoryProvider.overrideWithValue(repository),
          locationSearchRepositoryProvider.overrideWithValue(
            const _FakeLocationSearchRepository(),
          ),
        ],
        child: const MaterialApp(home: LocationAlarmSetupScreen()),
      ),
    );

    final button = tester.widget<InkWell>(
      find.byKey(const Key('location_alarm_map_center_button')),
    );
    button.onTap!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repository.currentLocationRequestCount, 1);
    expect(
      find.text(
        'Map centered on your current location. Tap to drop a pin if you want to use it as the destination.',
      ),
      findsOneWidget,
    );
  });
}

class _FakeAlarmRepository implements AlarmRepository {
  _FakeAlarmRepository({
    required this.diagnostics,
    this.currentLocationSnapshot,
  });

  final LocationAlarmSetupDiagnostics diagnostics;
  final CurrentLocationSnapshot? currentLocationSnapshot;
  int foregroundRequestCount = 0;
  int currentLocationRequestCount = 0;

  @override
  Future<LocationAlarmSetupDiagnostics> evaluateLocationTrigger(
    AlarmLocationTrigger trigger,
  ) async => diagnostics;

  @override
  Future<void> requestForegroundLocationPermission() async {
    foregroundRequestCount += 1;
  }

  @override
  Future<void> requestBackgroundLocationPermission() async {}

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<CurrentLocationSnapshot?> getCurrentLocationSnapshot() async {
    currentLocationRequestCount += 1;
    return currentLocationSnapshot;
  }

  @override
  Future<void> runLocationAlarmForegroundCheck() async {}

  @override
  Future<List<AlarmSpec>> listAlarms() async => const [];

  @override
  Future<AlarmSpec> upsertAlarm(AlarmSpec alarm) async => alarm;

  @override
  Future<void> deleteAlarm(String id) async {}

  @override
  Future<AlarmSpec> setAlarmEnabled({
    required String id,
    required bool enabled,
  }) {
    throw UnimplementedError();
  }

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
    throw UnimplementedError();
  }

  @override
  Future<void> refreshLocationAlarms() async {}

  @override
  Future<List<String>> listAvailableTimezones() async {
    return const ['UTC', 'America/Toronto', 'Asia/Dhaka'];
  }

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
    foregroundLocationGranted: false,
    backgroundLocationGranted: false,
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
  Future<MathAnswerSubmissionResult> submitMathAnswer(String answer) {
    throw UnimplementedError();
  }

  @override
  Future<void> requestBatteryOptimizationExemption() async {}

  @override
  Future<void> requestCameraPermission() async {}

  @override
  Future<void> requestActivityRecognitionPermission() async {}

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<void> requestNotificationPermission() async {}
}

class _FakeLocationSearchRepository implements LocationSearchRepository {
  const _FakeLocationSearchRepository();

  @override
  Future<List<LocationSearchResult>> search(String query) async => const [];
}
