import 'package:alarms_oss/src/features/alarms/domain/alarm_mission.dart';
import 'package:alarms_oss/src/features/alarms/domain/active_alarm_session.dart';
import 'package:alarms_oss/src/features/missions/presentation/math_mission_runner.dart';
import 'package:alarms_oss/src/platform/missions/mission_driver.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final missionRegistryProvider = Provider<MissionRegistry>((ref) {
  return const MissionRegistry([
    _DirectDismissMissionDriver(),
    MathMissionDriver(),
    _UnsupportedMissionDriver(type: AlarmMissionType.steps),
    _UnsupportedMissionDriver(type: AlarmMissionType.qr),
  ]);
});

class MissionRegistry {
  const MissionRegistry(this._drivers);

  final List<MissionDriver> _drivers;

  MissionDriver driverFor(AlarmMissionType type) {
    return _drivers.firstWhere((driver) => driver.type == type);
  }
}

class _DirectDismissMissionDriver implements MissionDriver {
  const _DirectDismissMissionDriver();

  @override
  AlarmMissionType get type => AlarmMissionType.none;

  @override
  Widget buildRunner({
    required BuildContext context,
    required ActiveAlarmSession session,
    required MissionActionCallbacks actions,
  }) {
    return const SizedBox.shrink();
  }
}

class _UnsupportedMissionDriver implements MissionDriver {
  const _UnsupportedMissionDriver({required this.type});

  @override
  final AlarmMissionType type;

  @override
  Widget buildRunner({
    required BuildContext context,
    required ActiveAlarmSession session,
    required MissionActionCallbacks actions,
  }) {
    return const SizedBox.shrink();
  }
}
