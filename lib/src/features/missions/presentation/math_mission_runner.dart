import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:neoalarm/src/features/alarms/domain/active_alarm_session.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';
import 'package:neoalarm/src/platform/missions/mission_driver.dart';
import 'package:flutter/material.dart';

class MathMissionDriver implements MissionDriver {
  const MathMissionDriver();

  @override
  AlarmMissionType get type => AlarmMissionType.math;

  @override
  Widget buildRunner({
    required BuildContext context,
    required ActiveAlarmSession session,
    required MissionActionCallbacks actions,
  }) {
    return MathMissionRunner(
      session: session,
      registerActivity: actions.registerActivity,
      submitMathAnswer: actions.submitMathAnswer,
    );
  }
}

class MathMissionRunner extends StatefulWidget {
  const MathMissionRunner({
    required this.session,
    required this.registerActivity,
    required this.submitMathAnswer,
    super.key,
  });

  final ActiveAlarmSession session;
  final Future<void> Function() registerActivity;
  final Future<MathAnswerSubmissionResult> Function(String answer)
  submitMathAnswer;

  @override
  State<MathMissionRunner> createState() => _MathMissionRunnerState();
}

class _MathMissionRunnerState extends State<MathMissionRunner> {
  late final TextEditingController _answerController;
  String? _feedbackText;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _answerController = TextEditingController();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MathMissionRunner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.sessionId != oldWidget.session.sessionId) {
      _answerController.clear();
      _feedbackText = null;
      _submitting = false;
      return;
    }

    final previousPrompt = oldWidget.session.mission.mathChallenge?.prompt;
    final currentPrompt = widget.session.mission.mathChallenge?.prompt;
    if (previousPrompt != currentPrompt) {
      _answerController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryForeground = NeoColors.foregroundOn(NeoColors.primary);
    final challenge = widget.session.mission.mathChallenge;

    if (challenge == null) {
      return NeoPanel(
        color: NeoColors.panel,
        child: Text(
          'Math mission data is unavailable for this session.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return NeoPanel(
      color: NeoColors.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeoPanel(
            color: NeoColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.session.mission.hasMultipleProblems) ...[
                  Text(
                    'Problem ${widget.session.mission.currentProblemNumber} of ${widget.session.mission.targetProblemCount}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: primaryForeground,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Center(
                  child: Text(
                    challenge.prompt,
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: primaryForeground,
                      fontSize: 52,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _answerController,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: const InputDecoration(hintText: 'Type the answer'),
            onChanged: (_) {
              widget.registerActivity();
            },
            onTap: () {
              widget.registerActivity();
            },
            onSubmitted: (_) => _submit(),
          ),
          if (_feedbackText != null) ...[
            const SizedBox(height: 10),
            Text(
              _feedbackText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _feedbackText!.startsWith('Wrong')
                    ? NeoColors.orange
                    : NeoColors.ink,
              ),
            ),
          ],
          const SizedBox(height: 16),
          NeoActionButton(
            label: _submitting ? 'Checking...' : 'Submit answer',
            expand: true,
            backgroundColor: NeoColors.cyan,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    setState(() {
      _submitting = true;
      _feedbackText = null;
    });

    await widget.registerActivity();
    final result = await widget.submitMathAnswer(_answerController.text);
    if (!mounted) {
      return;
    }

    final feedbackText = switch (result) {
      MathAnswerSubmissionResult.completed => null,
      MathAnswerSubmissionResult.advanced => () {
        final solvedCount = widget.session.mission.solvedProblemCount + 1;
        final remainingCount =
            widget.session.mission.targetProblemCount - solvedCount;
        return remainingCount > 0 ? 'Correct. $remainingCount left.' : null;
      }(),
      MathAnswerSubmissionResult.incorrect => 'Wrong answer. Try again.',
    };

    if (result != MathAnswerSubmissionResult.completed) {
      _answerController.clear();
    }

    setState(() {
      _submitting = false;
      _feedbackText = feedbackText;
    });
  }
}
