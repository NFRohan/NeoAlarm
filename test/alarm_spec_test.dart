import 'package:neoalarm/src/features/alarms/domain/alarm_spec.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_location_trigger.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes and deserializes alarm specs', () {
    final original = AlarmSpec(
      id: 'alarm-1',
      label: 'Morning',
      hour: 7,
      minute: 30,
      timezoneId: 'Asia/Dhaka',
      followsDeviceTimezone: false,
      enabled: true,
      weekdays: const [
        AlarmWeekday.monday,
        AlarmWeekday.wednesday,
        AlarmWeekday.friday,
      ],
      ringtone: AlarmRingtone.systemNotification,
      customToneId: null,
      customToneName: null,
      customToneHealthy: true,
      volumeRampEnabled: true,
      extraLoudEnabled: true,
      snoozeDurationMinutes: 9,
      maxSnoozes: 3,
      mission: const MissionSpec.math(
        difficulty: MathMissionDifficulty.hard,
        problemCount: 4,
      ),
      nextTriggerAtUtc: DateTime.utc(2026, 3, 12, 1, 30),
      skippedOccurrenceLocalDate: '2026-03-14',
    );

    final roundTrip = AlarmSpec.fromMap(original.toMap());

    expect(roundTrip.id, original.id);
    expect(roundTrip.label, original.label);
    expect(roundTrip.hour, original.hour);
    expect(roundTrip.minute, original.minute);
    expect(roundTrip.timezoneId, original.timezoneId);
    expect(roundTrip.followsDeviceTimezone, isFalse);
    expect(roundTrip.enabled, isTrue);
    expect(roundTrip.weekdays, original.weekdays);
    expect(roundTrip.ringtone, original.ringtone);
    expect(roundTrip.volumeRampEnabled, isTrue);
    expect(roundTrip.extraLoudEnabled, isTrue);
    expect(roundTrip.mission.type, original.mission.type);
    expect(roundTrip.mission.mathDifficulty, original.mission.mathDifficulty);
    expect(
      roundTrip.mission.mathProblemCount,
      original.mission.mathProblemCount,
    );
    expect(roundTrip.nextTriggerAtUtc, original.nextTriggerAtUtc);
    expect(
      roundTrip.skippedOccurrenceLocalDate,
      original.skippedOccurrenceLocalDate,
    );
  });

  test('uses one-time summary when no weekdays are selected', () {
    final alarm = AlarmSpec.createDraft(timezoneId: 'UTC');

    expect(alarm.repeatSummary, 'One time');
  });

  test('serializes and deserializes steps mission config', () {
    final original = AlarmSpec(
      id: 'alarm-2',
      label: 'Walk',
      hour: 6,
      minute: 45,
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
      maxSnoozes: 1,
      mission: const MissionSpec.steps(goal: 50),
      nextTriggerAtUtc: null,
      skippedOccurrenceLocalDate: null,
    );

    final roundTrip = AlarmSpec.fromMap(original.toMap());

    expect(roundTrip.mission.type, AlarmMissionType.steps);
    expect(roundTrip.mission.stepGoal, 50);
  });

  test('serializes and deserializes QR mission config', () {
    final original = AlarmSpec(
      id: 'alarm-3',
      label: 'Bathroom QR',
      hour: 8,
      minute: 15,
      timezoneId: 'UTC',
      enabled: true,
      weekdays: const [],
      ringtone: AlarmRingtone.systemAlarm,
      customToneId: null,
      customToneName: null,
      customToneHealthy: true,
      volumeRampEnabled: false,
      extraLoudEnabled: false,
      snoozeDurationMinutes: 9,
      maxSnoozes: 0,
      mission: const MissionSpec.qr(targetValue: 'sink-qr-target'),
      nextTriggerAtUtc: null,
      skippedOccurrenceLocalDate: null,
    );

    final roundTrip = AlarmSpec.fromMap(original.toMap());

    expect(roundTrip.mission.type, AlarmMissionType.qr);
    expect(roundTrip.mission.qrTargetValue, 'sink-qr-target');
    expect(roundTrip.mission.hasQrTarget, isTrue);
  });

  test('defaults new drafts to full-volume playback without skip state', () {
    final alarm = AlarmSpec.createDraft(timezoneId: 'UTC');

    expect(alarm.volumeRampEnabled, isFalse);
    expect(alarm.extraLoudEnabled, isFalse);
    expect(alarm.skippedOccurrenceLocalDate, isNull);
    expect(alarm.volumeSummary, 'Full volume');
  });

  test('treats only future or same-day skipped dates as pending', () {
    final pendingSkipAlarm = AlarmSpec(
      id: 'alarm-pending-skip',
      label: 'Commute',
      hour: 7,
      minute: 0,
      timezoneId: 'UTC',
      enabled: true,
      weekdays: const [AlarmWeekday.monday, AlarmWeekday.tuesday],
      ringtone: AlarmRingtone.systemAlarm,
      customToneId: null,
      customToneName: null,
      customToneHealthy: true,
      volumeRampEnabled: false,
      extraLoudEnabled: false,
      snoozeDurationMinutes: 9,
      maxSnoozes: 3,
      mission: const MissionSpec.none(),
      nextTriggerAtUtc: null,
      skippedOccurrenceLocalDate: '2099-01-01',
    );

    final staleSkipAlarm = pendingSkipAlarm.copyWith(
      skippedOccurrenceLocalDate: '2000-01-01',
    );

    expect(pendingSkipAlarm.hasPendingSkippedOccurrence, isTrue);
    expect(staleSkipAlarm.hasPendingSkippedOccurrence, isFalse);
  });

  test('summarizes specific timezones separately from device time', () {
    final localAlarm = AlarmSpec.createDraft(timezoneId: 'Asia/Dhaka');
    final anchoredAlarm = localAlarm.copyWith(
      followsDeviceTimezone: false,
      timezoneId: 'America/Toronto',
    );

    expect(localAlarm.timezoneSummary, 'Device time');
    expect(anchoredAlarm.usesSpecificTimezone, isTrue);
    expect(anchoredAlarm.timezoneSummary, 'Toronto time');
  });

  test('serializes and deserializes location alarm trigger config', () {
    final original = AlarmSpec(
      id: 'alarm-location-1',
      label: 'Banani stop',
      hour: 0,
      minute: 0,
      timezoneId: 'Asia/Dhaka',
      enabled: true,
      weekdays: const [],
      ringtone: AlarmRingtone.systemAlarm,
      customToneId: null,
      customToneName: null,
      customToneHealthy: true,
      volumeRampEnabled: false,
      extraLoudEnabled: false,
      snoozeDurationMinutes: 9,
      maxSnoozes: 0,
      mission: const MissionSpec.none(),
      nextTriggerAtUtc: null,
      skippedOccurrenceLocalDate: null,
      triggerKind: AlarmTriggerKind.location,
      locationTrigger: AlarmLocationTrigger(
        label: 'Banani Station',
        latitude: 23.7937,
        longitude: 90.4066,
        radiusMeters: 1000,
        health: AlarmLocationHealth.geofenceNotRegistered,
        geofenceId: 'geo-1',
        registeredAtUtc: DateTime.utc(2026, 3, 24, 12, 0),
        lastTransitionAtUtc: DateTime.utc(2026, 3, 24, 12, 30),
      ),
    );

    final roundTrip = AlarmSpec.fromMap(original.toMap());

    expect(roundTrip.triggerKind, AlarmTriggerKind.location);
    expect(roundTrip.isLocationAlarm, isTrue);
    expect(roundTrip.repeatSummary, 'Location trigger');
    expect(roundTrip.locationTrigger?.label, 'Banani Station');
    expect(
      roundTrip.locationTrigger?.health,
      AlarmLocationHealth.geofenceNotRegistered,
    );
    expect(roundTrip.locationTrigger?.geofenceId, 'geo-1');
    expect(
      roundTrip.locationTrigger?.registeredAtUtc,
      DateTime.utc(2026, 3, 24, 12, 0),
    );
    expect(
      roundTrip.locationTrigger?.lastTransitionAtUtc,
      DateTime.utc(2026, 3, 24, 12, 30),
    );
  });
}
