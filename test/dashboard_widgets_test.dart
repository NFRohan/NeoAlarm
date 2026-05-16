import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_location_trigger.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_spec.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';
import 'package:neoalarm/src/features/dashboard/presentation/widgets/dashboard_widgets.dart';

void main() {
  AlarmSpec buildAlarm({required String? skippedOccurrenceLocalDate}) {
    return AlarmSpec(
      id: 'alarm-1',
      label: 'Commute',
      hour: 7,
      minute: 30,
      timezoneId: 'UTC',
      enabled: true,
      weekdays: const [AlarmWeekday.monday, AlarmWeekday.tuesday],
      ringtone: AlarmRingtone.systemAlarm,
      customToneId: null,
      customToneName: null,
      customToneHealthy: true,
      volumeRampEnabled: false,
      extraLoudEnabled: false,
      snoozeDurationMinutes: 5,
      maxSnoozes: 3,
      mission: const MissionSpec.none(),
      nextTriggerAtUtc: null,
      skippedOccurrenceLocalDate: skippedOccurrenceLocalDate,
    );
  }

  Widget buildCard(AlarmSpec alarm) {
    return MaterialApp(
      home: Scaffold(
        body: AlarmCard(
          alarm: alarm,
          onEdit: () async {},
          onDelete: () async {},
          onSkipNext: () async {},
          onClearSkippedOccurrence: () async {},
          onRepairLocationAlarm: () async {},
          onToggle: (_) async {},
        ),
      ),
    );
  }

  AlarmSpec buildLocationAlarm({required AlarmLocationHealth health}) {
    return AlarmSpec.createLocationDraft(
      timezoneId: 'UTC',
      locationTrigger: AlarmLocationTrigger(
        label: 'Banani Station',
        latitude: 23.7936,
        longitude: 90.4066,
        radiusMeters: 1000,
        health: health,
      ),
    );
  }

  testWidgets('shows Skip next when no pending skip exists', (tester) async {
    await tester.pumpWidget(
      buildCard(buildAlarm(skippedOccurrenceLocalDate: null)),
    );

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(find.text('SKIP NEXT'), findsOneWidget);
    expect(find.text('UNDO SKIP'), findsNothing);
    expect(find.text('Skip next'), findsNothing);
  });

  testWidgets('shows Undo skip when a pending skip exists', (tester) async {
    await tester.pumpWidget(
      buildCard(buildAlarm(skippedOccurrenceLocalDate: '2099-01-01')),
    );

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(find.text('UNDO SKIP'), findsOneWidget);
    expect(find.text('SKIP NEXT'), findsOneWidget);
  });

  testWidgets('shows location repair action when alarm is unhealthy', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCard(
        buildLocationAlarm(health: AlarmLocationHealth.noBackgroundPermission),
      ),
    );

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(find.text('GRANT BACKGROUND ACCESS'), findsOneWidget);
  });
}
