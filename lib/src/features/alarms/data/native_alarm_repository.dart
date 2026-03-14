import 'package:neoalarm/src/features/alarms/data/alarm_repository.dart';
import 'package:neoalarm/src/features/alarms/domain/active_alarm_session.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_spec.dart';
import 'package:neoalarm/src/features/app_startup/domain/app_startup_context.dart';
import 'package:flutter/services.dart';

class NativeAlarmRepository implements AlarmRepository {
  const NativeAlarmRepository();

  static const _channel = MethodChannel('dev.neoalarm.app.alarm_engine');
  static const _sessionChannel = EventChannel(
    'dev.neoalarm.app.alarm_engine/active_session',
  );

  @override
  Future<AlarmEngineStatus> getStatus() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>('getStatus');
    return AlarmEngineStatus.fromMap(raw ?? const {});
  }

  @override
  Future<AppStartupContext> getStartupContext() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'getStartupContext',
    );
    return AppStartupContext.fromMap(raw ?? const {});
  }

  @override
  Future<ActiveAlarmSession?> getActiveAlarmSession() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'getActiveSession',
    );

    if (raw == null) {
      return null;
    }

    return ActiveAlarmSession.fromMap(raw);
  }

  @override
  Stream<ActiveAlarmSession?> watchActiveAlarmSession() async* {
    yield await getActiveAlarmSession();
    yield* _sessionChannel.receiveBroadcastStream().map((event) {
      if (event == null) {
        return null;
      }

      return ActiveAlarmSession.fromMap(event as Map<Object?, Object?>);
    });
  }

  @override
  Future<void> dismissActiveAlarmSession() {
    return _channel.invokeMethod<void>('dismissActiveSession');
  }

  @override
  Future<void> snoozeActiveAlarmSession() {
    return _channel.invokeMethod<void>('snoozeActiveSession');
  }

  @override
  Future<void> startMission() {
    return _channel.invokeMethod<void>('startMission');
  }

  @override
  Future<void> registerMissionActivity() {
    return _channel.invokeMethod<void>('registerMissionActivity');
  }

  @override
  Future<MathAnswerSubmissionResult> submitMathAnswer(String answer) async {
    final result = await _channel.invokeMethod<String>('submitMathAnswer', {
      'answer': answer,
    });
    return MathAnswerSubmissionResult.fromId(result);
  }

  @override
  Future<void> requestBatteryOptimizationExemption() {
    return _channel.invokeMethod<void>('requestBatteryOptimizationExemption');
  }

  @override
  Future<void> requestCameraPermission() {
    return _channel.invokeMethod<void>('requestCameraPermission');
  }

  @override
  Future<void> requestActivityRecognitionPermission() {
    return _channel.invokeMethod<void>('requestActivityRecognitionPermission');
  }

  @override
  Future<void> requestExactAlarmPermission() {
    return _channel.invokeMethod<void>('requestExactAlarmPermission');
  }

  @override
  Future<void> requestNotificationPermission() {
    return _channel.invokeMethod<void>('requestNotificationPermission');
  }

  @override
  Future<List<AlarmSpec>> listAlarms() async {
    final rawList =
        await _channel.invokeListMethod<Object?>('listAlarms') ?? const [];

    return rawList
        .cast<Map<Object?, Object?>>()
        .map(AlarmSpec.fromMap)
        .toList();
  }

  @override
  Future<AlarmSpec> setAlarmEnabled({
    required String id,
    required bool enabled,
  }) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'setAlarmEnabled',
      {'id': id, 'enabled': enabled},
    );

    return AlarmSpec.fromMap(raw ?? const {});
  }

  @override
  Future<AlarmSpec> skipNextOccurrence(String id) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'skipNextOccurrence',
      {'id': id},
    );
    return AlarmSpec.fromMap(raw ?? const {});
  }

  @override
  Future<AlarmSpec> clearSkippedOccurrence(String id) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'clearSkippedOccurrence',
      {'id': id},
    );
    return AlarmSpec.fromMap(raw ?? const {});
  }

  @override
  Future<void> deleteAlarm(String id) {
    return _channel.invokeMethod<void>('deleteAlarm', {'id': id});
  }

  @override
  Future<void> rescheduleAll() {
    return _channel.invokeMethod<void>('rescheduleAll');
  }

  @override
  Future<AlarmSpec> upsertAlarm(AlarmSpec alarm) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(
      'upsertAlarm',
      alarm.toMap(),
    );

    return AlarmSpec.fromMap(raw ?? const {});
  }
}
