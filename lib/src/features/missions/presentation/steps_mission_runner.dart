import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:neoalarm/src/features/alarms/domain/active_alarm_session.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';
import 'package:neoalarm/src/platform/missions/mission_driver.dart';
import 'package:flutter/material.dart';

class StepsMissionDriver implements MissionDriver {
  const StepsMissionDriver();

  @override
  AlarmMissionType get type => AlarmMissionType.steps;

  @override
  Widget buildRunner({
    required BuildContext context,
    required ActiveAlarmSession session,
    required MissionActionCallbacks actions,
  }) {
    return StepsMissionRunner(session: session, actions: actions);
  }
}

class StepsMissionRunner extends StatelessWidget {
  const StepsMissionRunner({
    required this.session,
    required this.actions,
    super.key,
  });

  final ActiveAlarmSession session;
  final MissionActionCallbacks actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stepProgress = session.mission.stepProgress;

    if (stepProgress == null) {
      return NeoPanel(
        child: Text(
          'Step mission data is unavailable for this session.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    if (stepProgress.isPermissionBlocked) {
      return NeoPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Movement access required',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Activity recognition permission was removed. Grant it again to keep counting steps.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            NeoActionButton(
              label: 'Grant activity access',
              expand: true,
              backgroundColor: NeoColors.cyan,
              onPressed: () async {
                await actions.requestActivityRecognitionPermission();
              },
            ),
          ],
        ),
      );
    }

    if (stepProgress.isUnsupported) {
      return NeoPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step sensor unavailable',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'This device is not reporting a live step detector for the active mission.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return NeoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Walk ${stepProgress.targetSteps} steps',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          NeoPanel(
            color: NeoColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stepProgress.completedSteps}/${stepProgress.targetSteps}',
                  style: theme.textTheme.displayMedium?.copyWith(fontSize: 48),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 18,
                    value: stepProgress.progressFraction.clamp(0, 1),
                    backgroundColor: NeoColors.panel,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      NeoColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            stepProgress.isAwaitingSteps
                ? 'Take your first step to start counting.'
                : '${stepProgress.remainingSteps} steps left.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
