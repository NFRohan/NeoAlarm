import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/features/alarms/application/active_alarm_session_controller.dart';
import 'package:neoalarm/src/features/alarms/presentation/active_alarm_screen.dart';
import 'package:neoalarm/src/features/app_startup/application/app_startup_controller.dart';
import 'package:neoalarm/src/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AlarmApp extends StatelessWidget {
  const AlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeoAlarm',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AlarmAppShell(),
    );
  }
}

class _AlarmAppShell extends ConsumerStatefulWidget {
  const _AlarmAppShell();

  @override
  ConsumerState<_AlarmAppShell> createState() => _AlarmAppShellState();
}

class _AlarmAppShellState extends ConsumerState<_AlarmAppShell>
    with WidgetsBindingObserver {
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
      ref.invalidate(appStartupContextProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startupContext = ref.watch(appStartupContextProvider);
    final session = ref.watch(activeAlarmSessionProvider);

    return startupContext.when(
      data: (startupContext) {
        return session.when(
          data: (session) {
            if (session != null) {
              return ActiveAlarmScreen(session: session);
            }

            if (startupContext.isDirectBootMode) {
              return const _DirectBootScreen();
            }

            return const DashboardScreen();
          },
          loading: () => const _AppLoadingScreen(),
          error: (error, stackTrace) {
            if (startupContext.isDirectBootMode) {
              return const _DirectBootScreen();
            }
            return const DashboardScreen();
          },
        );
      },
      loading: () => const _AppLoadingScreen(),
      error: (error, stackTrace) => session.when(
        data: (session) {
          if (session != null) {
            return ActiveAlarmScreen(session: session);
          }
          return const _DirectBootScreen();
        },
        loading: () => const _AppLoadingScreen(),
        error: (error, stackTrace) => const _DirectBootScreen(),
      ),
    );
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _DirectBootScreen extends StatelessWidget {
  const _DirectBootScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: DecoratedBox(
              decoration: neoPanelDecoration(color: NeoColors.panel),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DIRECT BOOT MODE',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Alarm-critical recovery is available before first unlock, but the full app stays locked down until Android reports the user as unlocked.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unlock the device to load the full dashboard and any nonessential startup work.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
