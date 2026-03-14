import 'package:neoalarm/src/app/app.dart';
import 'package:neoalarm/src/features/alarms/application/alarm_list_controller.dart';
import 'package:neoalarm/src/features/alarms/data/alarm_repository.dart';
import 'package:neoalarm/src/features/alarms/domain/active_alarm_session.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_spec.dart';
import 'package:neoalarm/src/features/app_startup/domain/app_startup_context.dart';
import 'package:neoalarm/src/features/onboarding/application/onboarding_controller.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      OnboardingController.completionKey: true,
    });
  });

  testWidgets('shows onboarding on first unlocked launch', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmRepositoryProvider.overrideWithValue(_FakeAlarmRepository()),
        ],
        child: const AlarmApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GET NEOALARM READY'), findsOneWidget);
    expect(find.text('START SETUP'), findsOneWidget);
    expect(find.text('NeoAlarm'), findsNothing);
  });

  testWidgets('renders dashboard shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmRepositoryProvider.overrideWithValue(_FakeAlarmRepository()),
        ],
        child: const AlarmApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NeoAlarm'), findsOneWidget);
    expect(find.text('READY TO RING'), findsNothing);
  });

  testWidgets('renders direct-boot-safe shell before unlock', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmRepositoryProvider.overrideWithValue(
            _FakeAlarmRepository(
              startupContext: const AppStartupContext(userUnlocked: false),
            ),
          ),
        ],
        child: const AlarmApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DIRECT BOOT MODE'), findsOneWidget);
    expect(find.textContaining('Unlock the device'), findsOneWidget);
  });

  testWidgets('finishes onboarding into the dashboard shell', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmRepositoryProvider.overrideWithValue(_FakeAlarmRepository()),
        ],
        child: const AlarmApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('START SETUP'));
    await tester.tap(find.text('START SETUP'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('CONTINUE'));
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('OPEN ALARMS'));
    await tester.tap(find.text('OPEN ALARMS'));
    await tester.pumpAndSettle();

    expect(find.text('NeoAlarm'), findsOneWidget);
  });

  testWidgets('system back from settings returns to home shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmRepositoryProvider.overrideWithValue(_FakeAlarmRepository()),
        ],
        child: const AlarmApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsNothing);
    expect(find.text('NeoAlarm'), findsOneWidget);
  });

  testWidgets('shows and toggles dark mode from settings', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmRepositoryProvider.overrideWithValue(_FakeAlarmRepository()),
        ],
        child: const AlarmApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, isNot(const Color(0xFF11151A)));

    await tester.tap(find.byType(NeoToggle));
    await tester.pumpAndSettle();

    final darkScaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(darkScaffold.backgroundColor, const Color(0xFF11151A));
  });
}

class _FakeAlarmRepository implements AlarmRepository {
  _FakeAlarmRepository({
    this.startupContext = const AppStartupContext(userUnlocked: true),
  });

  final AppStartupContext startupContext;

  @override
  Future<void> deleteAlarm(String id) async {}

  @override
  Future<void> dismissActiveAlarmSession() async {}

  @override
  Future<void> snoozeActiveAlarmSession() async {}

  @override
  Future<void> startMission() async {}

  @override
  Future<void> registerMissionActivity() async {}

  @override
  Future<MathAnswerSubmissionResult> submitMathAnswer(String answer) async {
    return MathAnswerSubmissionResult.incorrect;
  }

  @override
  Future<AlarmEngineStatus> getStatus() async {
    return const AlarmEngineStatus(
      canScheduleExactAlarms: true,
      notificationsEnabled: true,
      batteryOptimizationIgnored: false,
      hasCamera: true,
      cameraPermissionGranted: false,
      hasStepSensor: true,
      activityRecognitionGranted: false,
      timezoneId: 'UTC',
    );
  }

  @override
  Future<AppStartupContext> getStartupContext() async {
    return startupContext;
  }

  @override
  Future<ActiveAlarmSession?> getActiveAlarmSession() async {
    return null;
  }

  @override
  Stream<ActiveAlarmSession?> watchActiveAlarmSession() {
    return Stream<ActiveAlarmSession?>.value(null);
  }

  @override
  Future<void> requestActivityRecognitionPermission() async {}

  @override
  Future<void> requestBatteryOptimizationExemption() async {}

  @override
  Future<void> requestCameraPermission() async {}

  @override
  Future<void> requestExactAlarmPermission() async {}

  @override
  Future<void> requestNotificationPermission() async {}

  @override
  Future<List<AlarmSpec>> listAlarms() async {
    return const [];
  }

  @override
  Future<void> rescheduleAll() async {}

  @override
  Future<AlarmSpec> setAlarmEnabled({
    required String id,
    required bool enabled,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AlarmSpec> skipNextOccurrence(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<AlarmSpec> clearSkippedOccurrence(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<AlarmSpec> upsertAlarm(AlarmSpec alarm) async {
    return alarm;
  }
}
