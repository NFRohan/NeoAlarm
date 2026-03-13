class OnboardingState {
  const OnboardingState({required this.completed});

  final bool completed;

  bool get needsOnboarding => !completed;
}
