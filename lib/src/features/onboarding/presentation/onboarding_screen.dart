import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:neoalarm/src/features/alarms/application/alarm_list_controller.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:neoalarm/src/features/onboarding/application/onboarding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with WidgetsBindingObserver {
  int _stepIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(alarmEngineStatusProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = ref.watch(alarmEngineStatusProvider);

    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GET NEOALARM READY',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _stepIndex == 0
                              ? 'Set up the parts Android can block before you trust the alarm engine.'
                              : _stepIndex == 1
                              ? 'Walk through the system-level controls that matter for alarm reliability.'
                              : 'Mission permissions stay contextual and can be granted only when you choose those mission types.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: NeoColors.subtext,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  NeoPill(
                    label: '${_stepIndex + 1}/3',
                    backgroundColor: NeoColors.primary,
                    foregroundColor: NeoColors.accentInk,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _OnboardingStepProgress(stepIndex: _stepIndex),
              const SizedBox(height: 18),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: switch (_stepIndex) {
                    0 => _WelcomeStep(
                      key: const ValueKey('welcome-step'),
                      onStart: _goToNextStep,
                      onSkip: _finishOnboarding,
                    ),
                    1 => _ReliabilityStep(
                      key: const ValueKey('reliability-step'),
                      status: status,
                      onBack: _goToPreviousStep,
                      onContinue: _goToNextStep,
                      onSkip: _finishOnboarding,
                      onRequestExactAlarmAccess: () {
                        _runRepositoryAction(
                          () => ref
                              .read(alarmRepositoryProvider)
                              .requestExactAlarmPermission(),
                        );
                      },
                      onRequestNotificationAccess: () {
                        _runRepositoryAction(
                          () => ref
                              .read(alarmRepositoryProvider)
                              .requestNotificationPermission(),
                        );
                      },
                      onRequestBatteryOptimizationExemption: () {
                        _runRepositoryAction(
                          () => ref
                              .read(alarmRepositoryProvider)
                              .requestBatteryOptimizationExemption(),
                        );
                      },
                    ),
                    _ => _MissionPermissionStep(
                      key: const ValueKey('mission-step'),
                      status: status,
                      onBack: _goToPreviousStep,
                      onFinish: _finishOnboarding,
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToNextStep() {
    setState(() {
      _stepIndex = (_stepIndex + 1).clamp(0, 2);
    });
  }

  void _goToPreviousStep() {
    setState(() {
      _stepIndex = (_stepIndex - 1).clamp(0, 2);
    });
  }

  Future<void> _finishOnboarding() async {
    await ref.read(onboardingControllerProvider.notifier).completeOnboarding();
  }

  Future<void> _runRepositoryAction(Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(alarmEngineStatusProvider);
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? error.code)));
    }
  }
}

class _OnboardingStepProgress extends StatelessWidget {
  const _OnboardingStepProgress({required this.stepIndex});

  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        final isCompleted = index < stepIndex;
        final isActive = index == stepIndex;
        final color = isCompleted
            ? NeoColors.success
            : isActive
            ? NeoColors.primary
            : NeoColors.panel;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
            child: NeoPanel(
              color: color,
              padding: const EdgeInsets.symmetric(vertical: 10),
              borderWidth: 2,
              shadowOffset: const Offset(3, 3),
              child: Center(
                child: Text(
                  switch (index) {
                    0 => 'Welcome',
                    1 => 'Reliability',
                    _ => 'Mission policy',
                  }.toUpperCase(),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: NeoColors.foregroundOn(color),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    required this.onStart,
    required this.onSkip,
    super.key,
  });

  final VoidCallback onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NeoPanel(
            color: NeoColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEOALARM IS A RELIABILITY PRODUCT',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: NeoColors.accentInk,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Android can block exact wake-ups, mute foreground alarm affordances, or aggressively idle the app if setup is incomplete. This flow gets the high-impact system controls out of the way first.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NeoColors.accentInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _OnboardingCallout(
            title: 'Exact alarm access',
            detail: 'Required for precise alarm wake-up timing.',
            accent: NeoColors.orange,
            icon: Icons.alarm_on,
          ),
          const SizedBox(height: 12),
          const _OnboardingCallout(
            title: 'Notification access',
            detail: 'Required for the foreground alarm experience and full-screen handoff.',
            accent: NeoColors.cyan,
            icon: Icons.notifications_active,
          ),
          const SizedBox(height: 12),
          const _OnboardingCallout(
            title: 'Battery optimization',
            detail: 'Strongly recommended to reduce OEM interference, but not treated as a hard block.',
            accent: NeoColors.success,
            icon: Icons.battery_alert,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: NeoActionButton(
                  label: 'Not now',
                  backgroundColor: NeoColors.panel,
                  onPressed: onSkip,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeoActionButton(
                  label: 'Start setup',
                  expand: true,
                  onPressed: onStart,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReliabilityStep extends StatelessWidget {
  const _ReliabilityStep({
    required this.status,
    required this.onBack,
    required this.onContinue,
    required this.onSkip,
    required this.onRequestExactAlarmAccess,
    required this.onRequestNotificationAccess,
    required this.onRequestBatteryOptimizationExemption,
    super.key,
  });

  final AsyncValue<AlarmEngineStatus> status;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onRequestExactAlarmAccess;
  final VoidCallback onRequestNotificationAccess;
  final VoidCallback onRequestBatteryOptimizationExemption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return status.when(
      data: (status) {
        final isCoreReady =
            status.canScheduleExactAlarms && status.notificationsEnabled;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeoPanel(
                color: isCoreReady ? NeoColors.success : NeoColors.orange,
                child: Text(
                  isCoreReady
                      ? 'Exact alarms and notifications are ready. Battery optimization is still optional but recommended.'
                      : 'Finish the core Android controls here or continue knowing alarm trust is still provisional.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NeoColors.foregroundOn(
                      isCoreReady ? NeoColors.success : NeoColors.orange,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _OnboardingStatusCard(
                title: 'Exact alarm access',
                detail: status.canScheduleExactAlarms
                    ? 'Precise wake-up timing is available.'
                    : 'Without this, Android can block exact alarm delivery.',
                accent: status.canScheduleExactAlarms
                    ? NeoColors.success
                    : NeoColors.orange,
                actionLabel: status.canScheduleExactAlarms
                    ? 'Ready'
                    : 'Open settings',
                onAction: status.canScheduleExactAlarms
                    ? null
                    : onRequestExactAlarmAccess,
              ),
              const SizedBox(height: 12),
              _OnboardingStatusCard(
                title: 'Notifications',
                detail: status.notificationsEnabled
                    ? 'Foreground alarm notifications are allowed.'
                    : 'Alarm affordances are suppressed until notifications are enabled.',
                accent: status.notificationsEnabled
                    ? NeoColors.success
                    : NeoColors.orange,
                actionLabel: status.notificationsEnabled ? 'Ready' : 'Allow',
                onAction: status.notificationsEnabled
                    ? null
                    : onRequestNotificationAccess,
              ),
              const SizedBox(height: 12),
              _OnboardingStatusCard(
                title: 'Battery optimization',
                detail: status.batteryOptimizationIgnored
                    ? 'Background restrictions are already relaxed.'
                    : 'Recommended on Samsung and other aggressive OEM builds. This is not required to continue.',
                accent: status.batteryOptimizationIgnored
                    ? NeoColors.success
                    : NeoColors.cyan,
                actionLabel: status.batteryOptimizationIgnored
                    ? 'Ready'
                    : 'Recommended',
                onAction: status.batteryOptimizationIgnored
                    ? null
                    : onRequestBatteryOptimizationExemption,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: NeoActionButton(
                      label: 'Back',
                      backgroundColor: NeoColors.panel,
                      onPressed: onBack,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeoActionButton(
                      label: 'Not now',
                      backgroundColor: NeoColors.panel,
                      onPressed: onSkip,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeoActionButton(
                      label: isCoreReady ? 'Continue' : 'Continue anyway',
                      expand: true,
                      onPressed: onContinue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => NeoPanel(
        color: NeoColors.warm,
        child: Text('$error', style: theme.textTheme.bodyMedium),
      ),
    );
  }
}

class _MissionPermissionStep extends StatelessWidget {
  const _MissionPermissionStep({
    required this.status,
    required this.onBack,
    required this.onFinish,
    super.key,
  });

  final AsyncValue<AlarmEngineStatus> status;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return status.when(
      data: (status) {
        final readyCount = [
          status.canScheduleExactAlarms,
          status.notificationsEnabled,
          status.batteryOptimizationIgnored,
        ].where((value) => value).length;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeoPanel(
                color: NeoColors.cyan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MISSION PERMISSIONS STAY CONTEXTUAL',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: NeoColors.accentInk,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'NeoAlarm does not front-load camera or activity-recognition prompts. Those only appear when you choose QR or Steps missions in the editor.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: NeoColors.accentInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _OnboardingCallout(
                title: 'Current setup status',
                detail:
                    '$readyCount of 3 reliability checks are currently satisfied. You can always revisit the setup flow from Settings.',
                accent: readyCount >= 2 ? NeoColors.success : NeoColors.orange,
                icon: Icons.checklist,
              ),
              const SizedBox(height: 12),
              const _OnboardingCallout(
                title: 'QR mission',
                detail:
                    'Camera access is only requested when you configure or solve a QR-backed alarm.',
                accent: NeoColors.primary,
                icon: Icons.qr_code_scanner,
              ),
              const SizedBox(height: 12),
              const _OnboardingCallout(
                title: 'Steps mission',
                detail:
                    'Activity recognition is only requested when you choose a steps-backed alarm.',
                accent: NeoColors.success,
                icon: Icons.directions_walk,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: NeoActionButton(
                      label: 'Back',
                      backgroundColor: NeoColors.panel,
                      onPressed: onBack,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeoActionButton(
                      label: 'Open alarms',
                      expand: true,
                      onPressed: onFinish,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => NeoPanel(
        color: NeoColors.warm,
        child: Text('$error', style: theme.textTheme.bodyMedium),
      ),
    );
  }
}

class _OnboardingCallout extends StatelessWidget {
  const _OnboardingCallout({
    required this.title,
    required this.detail,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String detail;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NeoPanel(
      color: NeoColors.panel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent,
              border: Border.all(color: NeoColors.ink, width: 2),
            ),
            child: Icon(icon, size: 22, color: NeoColors.foregroundOn(accent)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NeoColors.subtext,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStatusCard extends StatelessWidget {
  const _OnboardingStatusCard({
    required this.title,
    required this.detail,
    required this.accent,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String detail;
  final Color accent;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NeoPanel(
      color: NeoColors.panel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: NeoColors.ink, width: 2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NeoColors.subtext,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          NeoActionButton(
            label: actionLabel,
            compact: true,
            backgroundColor: onAction == null ? NeoColors.muted : NeoColors.primary,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}
