import 'package:alarms_oss/src/core/theme/app_theme.dart';
import 'package:alarms_oss/src/core/ui/neo_brutal_widgets.dart';
import 'package:alarms_oss/src/features/alarms/application/active_alarm_session_controller.dart';
import 'package:alarms_oss/src/features/alarms/domain/active_alarm_session.dart';
import 'package:alarms_oss/src/features/missions/application/mission_registry.dart';
import 'package:alarms_oss/src/platform/missions/mission_driver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActiveAlarmScreen extends ConsumerWidget {
  const ActiveAlarmScreen({required this.session, super.key});

  final ActiveAlarmSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final formattedTime = localizations.formatTimeOfDay(
      TimeOfDay(hour: session.hour, minute: session.minute),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final missionRegistry = ref.watch(missionRegistryProvider);
    final missionDriver = missionRegistry.driverFor(session.mission.spec.type);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: NeoColors.primary,
        body: Stack(
          children: [
            Positioned(
              top: 90,
              left: -24,
              child: Text(
                'Z',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: NeoColors.ink.withValues(alpha: 0.08),
                  fontSize: 160,
                ),
              ),
            ),
            Positioned(
              right: -16,
              bottom: 110,
              child: Transform.rotate(
                angle: 0.18,
                child: Container(
                  width: 170,
                  height: 170,
                  color: NeoColors.ink.withValues(alpha: 0.05),
                  alignment: Alignment.center,
                  child: Text(
                    'Z',
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: NeoColors.ink.withValues(alpha: 0.09),
                      fontSize: 120,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Column(
                  children: [
                    Row(
                      children: [
                        NeoPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          borderWidth: 2,
                          shadowOffset: const Offset(3, 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.alarm, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                session.requiresMission
                                    ? 'MISSION REQUIRED'
                                    : 'ACTIVE ALARM',
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        NeoPanel(
                          padding: const EdgeInsets.all(9),
                          borderWidth: 2,
                          shadowOffset: const Offset(3, 3),
                          child: Text(
                            '${session.snoozeCount}/${session.maxSnoozes}',
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    formattedTime,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.displayLarge
                                        ?.copyWith(
                                          fontSize:
                                              MediaQuery.sizeOf(context).width >
                                                  420
                                              ? 110
                                              : 74,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    session.alarmLabel.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineLarge,
                                  ),
                                  const SizedBox(height: 28),
                                  if (session.requiresMission)
                                    missionDriver.buildRunner(
                                      context: context,
                                      session: session,
                                      actions: MissionActionCallbacks(
                                        submitMathAnswer: (answer) async {
                                          try {
                                            return await ref
                                                .read(
                                                  activeAlarmSessionControllerProvider,
                                                )
                                                .submitMathAnswer(answer);
                                          } on PlatformException catch (error) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    error.message ?? error.code,
                                                  ),
                                                ),
                                              );
                                            }
                                            return false;
                                          }
                                        },
                                      ),
                                    )
                                  else
                                    NeoActionButton(
                                      label: 'Dismiss',
                                      expand: true,
                                      backgroundColor: NeoColors.panel,
                                      onPressed: () => _runAction(
                                        context,
                                        () => ref
                                            .read(
                                              activeAlarmSessionControllerProvider,
                                            )
                                            .dismiss(),
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  NeoActionButton(
                                    label: session.canSnooze
                                        ? 'Snooze ${session.snoozeDurationMinutes} min'
                                        : 'Snooze limit reached',
                                    expand: true,
                                    backgroundColor: NeoColors.warm,
                                    onPressed: session.canSnooze
                                        ? () => _runAction(
                                            context,
                                            () => ref
                                                .read(
                                                  activeAlarmSessionControllerProvider,
                                                )
                                                .snooze(),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on PlatformException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? error.code)));
    }
  }
}
