enum AlarmMissionType {
  none('none', 'Direct dismiss', 'Dismiss button is immediately available.'),
  math('math', 'Math mission', 'Solve a math challenge to dismiss.'),
  steps(
    'steps',
    'Steps mission',
    'Requires a step sensor and activity recognition.',
  ),
  qr('qr', 'QR mission', 'Requires a camera and camera permission.');

  const AlarmMissionType(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static AlarmMissionType fromId(String? value) {
    return AlarmMissionType.values.firstWhere(
      (missionType) => missionType.id == value,
      orElse: () => AlarmMissionType.none,
    );
  }
}

enum MathMissionDifficulty {
  easy('easy', 'Easy'),
  standard('standard', 'Standard'),
  hard('hard', 'Hard');

  const MathMissionDifficulty(this.id, this.label);

  final String id;
  final String label;

  static MathMissionDifficulty fromId(String? value) {
    return MathMissionDifficulty.values.firstWhere(
      (difficulty) => difficulty.id == value,
      orElse: () => MathMissionDifficulty.standard,
    );
  }
}

class MissionSpec {
  const MissionSpec({
    required this.type,
    this.mathDifficulty = MathMissionDifficulty.standard,
  });

  const MissionSpec.none() : this(type: AlarmMissionType.none);

  const MissionSpec.math({
    MathMissionDifficulty difficulty = MathMissionDifficulty.standard,
  }) : this(type: AlarmMissionType.math, mathDifficulty: difficulty);

  const MissionSpec.steps() : this(type: AlarmMissionType.steps);

  const MissionSpec.qr() : this(type: AlarmMissionType.qr);

  factory MissionSpec.fromMap(
    Map<Object?, Object?>? raw, {
    String? fallbackType,
  }) {
    final type = AlarmMissionType.fromId(
      (raw?['type'] ?? fallbackType) as String?,
    );
    final config = raw?['config'] as Map<Object?, Object?>?;

    return switch (type) {
      AlarmMissionType.none => const MissionSpec.none(),
      AlarmMissionType.math => MissionSpec.math(
        difficulty: MathMissionDifficulty.fromId(
          config?['difficulty'] as String?,
        ),
      ),
      AlarmMissionType.steps => const MissionSpec.steps(),
      AlarmMissionType.qr => const MissionSpec.qr(),
    };
  }

  final AlarmMissionType type;
  final MathMissionDifficulty mathDifficulty;

  bool get isDirectDismiss => type == AlarmMissionType.none;

  String get summary {
    return switch (type) {
      AlarmMissionType.none => type.label,
      AlarmMissionType.math => '${type.label} · ${mathDifficulty.label}',
      AlarmMissionType.steps => type.label,
      AlarmMissionType.qr => type.label,
    };
  }

  Map<String, Object?> toMap() {
    return {
      'type': type.id,
      'config': switch (type) {
        AlarmMissionType.math => {'difficulty': mathDifficulty.id},
        _ => <String, Object?>{},
      },
    };
  }

  MissionSpec copyWith({
    AlarmMissionType? type,
    MathMissionDifficulty? mathDifficulty,
  }) {
    final resolvedType = type ?? this.type;
    return switch (resolvedType) {
      AlarmMissionType.none => const MissionSpec.none(),
      AlarmMissionType.math => MissionSpec.math(
        difficulty: mathDifficulty ?? this.mathDifficulty,
      ),
      AlarmMissionType.steps => const MissionSpec.steps(),
      AlarmMissionType.qr => const MissionSpec.qr(),
    };
  }
}

enum ActiveAlarmSessionState {
  ringing('ringing'),
  snoozed('snoozed');

  const ActiveAlarmSessionState(this.id);

  final String id;

  static ActiveAlarmSessionState fromId(String? value) {
    return ActiveAlarmSessionState.values.firstWhere(
      (state) => state.id == value,
      orElse: () => ActiveAlarmSessionState.ringing,
    );
  }
}

enum ActiveMissionStatus {
  pending('pending'),
  completed('completed');

  const ActiveMissionStatus(this.id);

  final String id;

  static ActiveMissionStatus fromId(String? value) {
    return ActiveMissionStatus.values.firstWhere(
      (status) => status.id == value,
      orElse: () => ActiveMissionStatus.pending,
    );
  }
}

class MathChallengeSnapshot {
  const MathChallengeSnapshot({
    required this.leftOperand,
    required this.rightOperand,
    required this.operatorSymbol,
    required this.attemptCount,
  });

  factory MathChallengeSnapshot.fromMap(Map<Object?, Object?> raw) {
    return MathChallengeSnapshot(
      leftOperand: (raw['leftOperand']! as num).toInt(),
      rightOperand: (raw['rightOperand']! as num).toInt(),
      operatorSymbol: raw['operatorSymbol']! as String,
      attemptCount: (raw['attemptCount']! as num).toInt(),
    );
  }

  final int leftOperand;
  final int rightOperand;
  final String operatorSymbol;
  final int attemptCount;

  String get prompt => '$leftOperand $operatorSymbol $rightOperand';
}

class ActiveMissionSnapshot {
  const ActiveMissionSnapshot({
    required this.spec,
    required this.status,
    this.mathChallenge,
  });

  factory ActiveMissionSnapshot.fromMap(Map<Object?, Object?>? raw) {
    final missionRaw = raw ?? const <Object?, Object?>{};
    final challengeRaw = missionRaw['mathChallenge'] as Map<Object?, Object?>?;

    return ActiveMissionSnapshot(
      spec: MissionSpec.fromMap(missionRaw),
      status: ActiveMissionStatus.fromId(missionRaw['status'] as String?),
      mathChallenge: challengeRaw == null
          ? null
          : MathChallengeSnapshot.fromMap(challengeRaw),
    );
  }

  final MissionSpec spec;
  final ActiveMissionStatus status;
  final MathChallengeSnapshot? mathChallenge;

  bool get isCompleted => status == ActiveMissionStatus.completed;
}
