import 'package:alarms_oss/src/core/theme/app_theme.dart';
import 'package:alarms_oss/src/core/ui/neo_brutal_widgets.dart';
import 'package:alarms_oss/src/features/alarms/domain/active_alarm_session.dart';
import 'package:alarms_oss/src/features/alarms/domain/alarm_mission.dart';
import 'package:alarms_oss/src/platform/missions/mission_driver.dart';
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
      submitMathAnswer: actions.submitMathAnswer,
    );
  }
}

class MathMissionRunner extends StatefulWidget {
  const MathMissionRunner({
    required this.session,
    required this.submitMathAnswer,
    super.key,
  });

  final ActiveAlarmSession session;
  final Future<bool> Function(String answer) submitMathAnswer;

  @override
  State<MathMissionRunner> createState() => _MathMissionRunnerState();
}

class _MathMissionRunnerState extends State<MathMissionRunner> {
  late final TextEditingController _answerController;
  String? _errorText;
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
      _errorText = null;
      _submitting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            child: Center(
              child: Text(
                challenge.prompt,
                style: theme.textTheme.displayMedium?.copyWith(fontSize: 52),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _answerController,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: const InputDecoration(hintText: 'Type the answer'),
            onSubmitted: (_) => _submit(),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: NeoColors.orange,
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
      _errorText = null;
    });

    final accepted = await widget.submitMathAnswer(_answerController.text);
    if (!mounted) {
      return;
    }

    if (accepted) {
      setState(() {
        _submitting = false;
      });
      return;
    }

    _answerController.clear();
    setState(() {
      _submitting = false;
      _errorText = 'Wrong answer. Try again.';
    });
  }
}
