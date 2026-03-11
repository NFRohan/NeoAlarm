import 'package:alarms_oss/src/features/alarms/application/alarm_list_controller.dart';
import 'package:alarms_oss/src/features/alarms/data/alarm_repository.dart';
import 'package:alarms_oss/src/features/alarms/domain/active_alarm_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final activeAlarmSessionProvider = FutureProvider<ActiveAlarmSession?>(
  (ref) => ref.watch(alarmRepositoryProvider).getActiveAlarmSession(),
);

final activeAlarmSessionControllerProvider =
    Provider<ActiveAlarmSessionController>(
      (ref) => ActiveAlarmSessionController(ref),
    );

class ActiveAlarmSessionController {
  const ActiveAlarmSessionController(this._ref);

  final Ref _ref;

  AlarmRepository get _repository => _ref.read(alarmRepositoryProvider);

  Future<void> dismiss() async {
    await _repository.dismissActiveAlarmSession();
    _ref.invalidate(activeAlarmSessionProvider);
    _ref.invalidate(alarmListControllerProvider);
  }

  Future<void> snooze() async {
    await _repository.snoozeActiveAlarmSession();
    _ref.invalidate(activeAlarmSessionProvider);
    _ref.invalidate(alarmListControllerProvider);
  }

  Future<bool> submitMathAnswer(String answer) async {
    final accepted = await _repository.submitMathAnswer(answer);
    _ref.invalidate(activeAlarmSessionProvider);
    _ref.invalidate(alarmListControllerProvider);
    return accepted;
  }

  void refresh() {
    _ref.invalidate(activeAlarmSessionProvider);
  }
}
