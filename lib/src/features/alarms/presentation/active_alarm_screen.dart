import 'package:alarms_oss/src/core/theme/app_theme.dart';
import 'package:alarms_oss/src/core/ui/neo_brutal_widgets.dart';
import 'package:alarms_oss/src/features/alarms/application/active_alarm_session_controller.dart';
import 'package:alarms_oss/src/features/alarms/domain/active_alarm_session.dart';
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
                        const NeoPanel(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          borderWidth: 2,
                          shadowOffset: Offset(3, 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.alarm, size: 18),
                              SizedBox(width: 8),
                              Text('ACTIVE ALARM'),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const NeoPanel(
                          padding: EdgeInsets.all(9),
                          borderWidth: 2,
                          shadowOffset: Offset(3, 3),
                          child: Icon(Icons.battery_charging_full, size: 22),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const NeoPill(
                      label: 'Alarm ringing',
                      backgroundColor: NeoColors.orange,
                    ),
                    const SizedBox(height: 22),
                    Text(
                      formattedTime,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: MediaQuery.sizeOf(context).width > 420
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
                    NeoActionButton(
                      label: 'Dismiss',
                      expand: true,
                      backgroundColor: NeoColors.panel,
                      onPressed: () async {
                        try {
                          await ref
                              .read(activeAlarmSessionControllerProvider)
                              .dismiss();
                        } on PlatformException catch (error) {
                          if (!context.mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error.message ?? error.code),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const NeoActionButton(
                      label: 'Snooze (next sprint)',
                      expand: true,
                      backgroundColor: NeoColors.warm,
                    ),
                    const Spacer(),
                    NeoPanel(
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            color: NeoColors.cyan,
                            alignment: Alignment.center,
                            child: const Icon(Icons.calculate),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Active mission',
                                  style: theme.textTheme.labelMedium,
                                ),
                                Text(
                                  session.missionType == 'none'
                                      ? 'DIRECT DISMISS'
                                      : session.missionType.toUpperCase(),
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${localizations.formatFullDate(session.startedAtLocal)}  |  Snooze ${session.snoozeCount}/${session.maxSnoozes}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: NeoColors.ink,
                                width: 2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Text('!'),
                          ),
                        ],
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
}
