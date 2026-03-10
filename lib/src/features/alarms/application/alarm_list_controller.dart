import 'package:alarms_oss/src/features/alarms/data/alarm_repository.dart';
import 'package:alarms_oss/src/features/alarms/data/native_alarm_repository.dart';
import 'package:alarms_oss/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:alarms_oss/src/features/alarms/domain/alarm_spec.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final alarmRepositoryProvider = Provider<AlarmRepository>(
  (ref) => const NativeAlarmRepository(),
);

final alarmEngineStatusProvider = FutureProvider<AlarmEngineStatus>(
  (ref) => ref.watch(alarmRepositoryProvider).getStatus(),
);

final alarmListControllerProvider =
    AsyncNotifierProvider<AlarmListController, List<AlarmSpec>>(
      AlarmListController.new,
    );

class AlarmListController extends AsyncNotifier<List<AlarmSpec>> {
  AlarmRepository get _repository => ref.read(alarmRepositoryProvider);

  @override
  Future<List<AlarmSpec>> build() async {
    return _sort(await _repository.listAlarms());
  }

  Future<void> reload() async {
    state = AsyncData(_sort(await _repository.listAlarms()));
  }

  Future<void> saveAlarm(AlarmSpec alarm) async {
    final saved = await _repository.upsertAlarm(alarm);
    final current = state.asData?.value ?? await _repository.listAlarms();

    state = AsyncData(
      _sort([...current.where((entry) => entry.id != saved.id), saved]),
    );
  }

  Future<void> deleteAlarm(String id) async {
    await _repository.deleteAlarm(id);
    final current = state.asData?.value ?? await _repository.listAlarms();

    state = AsyncData(
      current.where((alarm) => alarm.id != id).toList(growable: false),
    );
  }

  Future<void> setEnabled({required String id, required bool enabled}) async {
    final updated = await _repository.setAlarmEnabled(id: id, enabled: enabled);
    final current = state.asData?.value ?? await _repository.listAlarms();

    state = AsyncData(
      _sort([...current.where((entry) => entry.id != updated.id), updated]),
    );
  }

  Future<void> rescheduleAll() async {
    await _repository.rescheduleAll();
    await reload();
  }

  List<AlarmSpec> _sort(List<AlarmSpec> alarms) {
    final sorted = [...alarms];
    sorted.sort((left, right) {
      final leftTrigger =
          left.nextTriggerAtUtc?.millisecondsSinceEpoch ?? 9223372036854775807;
      final rightTrigger =
          right.nextTriggerAtUtc?.millisecondsSinceEpoch ?? 9223372036854775807;

      final triggerCompare = leftTrigger.compareTo(rightTrigger);
      if (triggerCompare != 0) {
        return triggerCompare;
      }

      final hourCompare = left.hour.compareTo(right.hour);
      if (hourCompare != 0) {
        return hourCompare;
      }

      return left.minute.compareTo(right.minute);
    });
    return sorted;
  }
}
