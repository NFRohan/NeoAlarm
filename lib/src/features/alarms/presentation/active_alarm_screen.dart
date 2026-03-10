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
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF14080E), Color(0xFF5A1420), Color(0xFFC44536)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x26FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Alarm ringing',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formattedTime,
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -3,
                      height: 0.92,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    session.alarmLabel,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Native audio, vibration, and the foreground service are active. Mission enforcement is the next layer on top of this ring session.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFF7D8D4),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _AlarmSessionStat(
                    label: 'Mission',
                    value: session.missionType == 'none'
                        ? 'Direct dismiss'
                        : session.missionType,
                  ),
                  const SizedBox(height: 12),
                  _AlarmSessionStat(
                    label: 'Started',
                    value: localizations.formatFullDate(session.startedAtLocal),
                  ),
                  const SizedBox(height: 12),
                  _AlarmSessionStat(
                    label: 'Snooze budget',
                    value: '${session.snoozeCount}/${session.maxSnoozes}',
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF4EA),
                        foregroundColor: const Color(0xFF311012),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        textStyle: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
                      child: const Text('Dismiss alarm'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlarmSessionStat extends StatelessWidget {
  const _AlarmSessionStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFF7D8D4),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
