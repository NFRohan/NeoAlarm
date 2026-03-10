import 'package:alarms_oss/src/features/alarms/data/alarm_repository.dart';
import 'package:alarms_oss/src/features/alarms/domain/active_alarm_session.dart';
import 'package:alarms_oss/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:alarms_oss/src/features/alarms/domain/alarm_spec.dart';
import 'package:flutter/services.dart';

class NativeAlarmRepository implements AlarmRepository {
  const NativeAlarmRepository();

  static const _channel = MethodChannel('dev.alarmsoss.alarm_engine');

  @override
  Future<AlarmEngineStatus> getStatus() async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>('getStatus');
    return AlarmEngineStatus.fromMap(raw ?? const {});
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
  Future<void> dismissActiveAlarmSession() {
    return _channel.invokeMethod<void>('dismissActiveSession');
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
