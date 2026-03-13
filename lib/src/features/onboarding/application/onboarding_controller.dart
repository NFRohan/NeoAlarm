import 'package:neoalarm/src/features/app_startup/application/app_startup_controller.dart';
import 'package:neoalarm/src/features/onboarding/domain/onboarding_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

class OnboardingController extends AsyncNotifier<OnboardingState> {
  static const completionKey = 'app.onboarding.completed';

  @override
  Future<OnboardingState> build() async {
    final startupContext = await ref.watch(appStartupContextProvider.future);
    if (startupContext.isDirectBootMode) {
      return const OnboardingState(completed: true);
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      final completed = preferences.getBool(completionKey) ?? false;
      return OnboardingState(completed: completed);
    } catch (_) {
      return const OnboardingState(completed: false);
    }
  }

  Future<void> completeOnboarding() async {
    state = const AsyncData(OnboardingState(completed: true));
    await _persistCompletion(true);
  }

  Future<void> resetOnboarding() async {
    state = const AsyncData(OnboardingState(completed: false));
    await _persistCompletion(false);
  }

  Future<void> _persistCompletion(bool completed) async {
    final startupContext = await ref.read(appStartupContextProvider.future);
    if (startupContext.isDirectBootMode) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(completionKey, completed);
  }
}
