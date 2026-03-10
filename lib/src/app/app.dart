import 'package:alarms_oss/src/core/theme/app_theme.dart';
import 'package:alarms_oss/src/features/alarms/application/active_alarm_session_controller.dart';
import 'package:alarms_oss/src/features/alarms/presentation/active_alarm_screen.dart';
import 'package:alarms_oss/src/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AlarmApp extends StatelessWidget {
  const AlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'alarms-oss',
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
      ref.read(activeAlarmSessionControllerProvider).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeAlarmSessionProvider);

    return session.when(
      data: (session) {
        if (session != null) {
          return ActiveAlarmScreen(session: session);
        }

        return const DashboardScreen();
      },
      loading: () => const _AppLoadingScreen(),
      error: (error, stackTrace) => const DashboardScreen(),
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
