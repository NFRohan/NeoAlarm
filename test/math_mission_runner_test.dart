import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoalarm/src/features/alarms/domain/active_alarm_session.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';
import 'package:neoalarm/src/features/missions/presentation/math_mission_runner.dart';

void main() {
  testWidgets('keeps math answer input focused across problem changes', (
    tester,
  ) async {
    var session = _buildSession(
      solvedProblemCount: 0,
      challenge: const MathChallengeSnapshot(
        leftOperand: 2,
        rightOperand: 3,
        operatorSymbol: '+',
        attemptCount: 0,
      ),
    );
    late StateSetter updateHarness;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateHarness = setState;
              return MathMissionRunner(
                session: session,
                registerActivity: () async {},
                submitMathAnswer: (_) async {
                  updateHarness(() {
                    session = _buildSession(
                      solvedProblemCount: 1,
                      challenge: const MathChallengeSnapshot(
                        leftOperand: 4,
                        rightOperand: 5,
                        operatorSymbol: '+',
                        attemptCount: 0,
                      ),
                    );
                  });
                  return MathAnswerSubmissionResult.advanced;
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialInput = tester.widget<EditableText>(find.byType(EditableText));
    expect(initialInput.focusNode.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.text('SUBMIT ANSWER'));
    await tester.pumpAndSettle();

    expect(find.text('4 + 5'), findsOneWidget);
    final updatedInput = tester.widget<EditableText>(find.byType(EditableText));
    expect(updatedInput.focusNode.hasFocus, isTrue);
  });
}

ActiveAlarmSession _buildSession({
  required int solvedProblemCount,
  required MathChallengeSnapshot challenge,
}) {
  return ActiveAlarmSession(
    sessionId: 'session-1',
    alarmId: 'alarm-1',
    alarmLabel: 'Wake up',
    hour: 7,
    minute: 30,
    state: ActiveAlarmSessionState.missionActive,
    mission: ActiveMissionSnapshot(
      spec: const MissionSpec.math(problemCount: 2),
      status: ActiveMissionStatus.pending,
      solvedProblemCount: solvedProblemCount,
      targetProblemCount: 2,
      mathChallenge: challenge,
    ),
    startedAtUtc: DateTime.utc(2026, 5, 18, 1, 0),
    snoozeCount: 0,
    maxSnoozes: 3,
    snoozeDurationMinutes: 5,
    missionTimeoutAtUtc: DateTime.utc(2026, 5, 18, 1, 1),
  );
}
