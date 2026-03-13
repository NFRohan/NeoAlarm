import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_engine_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.status,
    required this.themeMode,
    required this.onBack,
    required this.onSetDarkModeEnabled,
    required this.onRequestExactAlarmAccess,
    required this.onRequestNotificationAccess,
    required this.onRequestBatteryOptimizationExemption,
    required this.onRequestCameraPermission,
    required this.onRequestActivityRecognitionPermission,
    required this.onRunOnboarding,
    super.key,
  });

  final AsyncValue<AlarmEngineStatus> status;
  final AsyncValue<ThemeMode> themeMode;
  final VoidCallback onBack;
  final ValueChanged<bool> onSetDarkModeEnabled;
  final VoidCallback onRequestExactAlarmAccess;
  final VoidCallback onRequestNotificationAccess;
  final VoidCallback onRequestBatteryOptimizationExemption;
  final VoidCallback onRequestCameraPermission;
  final VoidCallback onRequestActivityRecognitionPermission;
  final Future<void> Function() onRunOnboarding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NeoSquareIconButton(
                icon: Icons.arrow_back,
                backgroundColor: NeoColors.warm,
                size: 52,
                onPressed: onBack,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SETTINGS',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Diagnostics, permissions, and system-level controls.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: NeoColors.subtext,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          NeoPanel(
            color: NeoColors.cyan,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LOCAL-FIRST',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: NeoColors.accentInk,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Everything stays on-device. Use this page to clear Android warnings before relying on alarm missions.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NeoColors.accentInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _AppearanceSection(
            themeMode: themeMode,
            onSetDarkModeEnabled: onSetDarkModeEnabled,
          ),
          const SizedBox(height: 18),
          _SetupFlowSection(onRunOnboarding: onRunOnboarding),
          const SizedBox(height: 18),
          _AlarmReadinessCard(status: status),
          const SizedBox(height: 18),
          _DeviceDiagnosticsSection(
            status: status,
            onRequestExactAlarmAccess: onRequestExactAlarmAccess,
            onRequestNotificationAccess: onRequestNotificationAccess,
            onRequestBatteryOptimizationExemption:
                onRequestBatteryOptimizationExemption,
            onRequestCameraPermission: onRequestCameraPermission,
            onRequestActivityRecognitionPermission:
                onRequestActivityRecognitionPermission,
          ),
        ],
      ),
    );
  }
}

class _SetupFlowSection extends StatelessWidget {
  const _SetupFlowSection({required this.onRunOnboarding});

  final Future<void> Function() onRunOnboarding;

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
              color: NeoColors.primary,
              border: Border.all(color: NeoColors.ink, width: 2),
            ),
            child: const Icon(
              Icons.rocket_launch,
              size: 24,
              color: NeoColors.accentInk,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Setup flow', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Replay the first-run onboarding to walk through alarm-critical Android controls in order.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NeoColors.subtext,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          NeoActionButton(
            label: 'Run again',
            compact: true,
            onPressed: () {
              onRunOnboarding();
            },
          ),
        ],
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    required this.themeMode,
    required this.onSetDarkModeEnabled,
  });

  final AsyncValue<ThemeMode> themeMode;
  final ValueChanged<bool> onSetDarkModeEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkModeEnabled = themeMode.asData?.value == ThemeMode.dark;
    final isLoading = themeMode.isLoading;

    return NeoPanel(
      color: NeoColors.panel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: NeoColors.success,
              border: Border.all(color: NeoColors.ink, width: 2),
            ),
            child: const Icon(
              Icons.dark_mode,
              size: 24,
              color: NeoColors.accentInk,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  isDarkModeEnabled
                      ? 'Dark mode is enabled for the main app shell.'
                      : 'Use the light neobrutalist palette or switch to a darker shell.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NeoColors.subtext,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Dark mode', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          const SizedBox(width: 12),
          NeoToggle(
            value: isDarkModeEnabled,
            onChanged: isLoading ? null : onSetDarkModeEnabled,
          ),
        ],
      ),
    );
  }
}

class _AlarmReadinessCard extends StatelessWidget {
  const _AlarmReadinessCard({required this.status});

  final AsyncValue<AlarmEngineStatus> status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return status.when(
      data: (status) {
        final isHealthy =
            status.canScheduleExactAlarms && status.notificationsEnabled;
        final accent = isHealthy ? NeoColors.success : NeoColors.orange;
        final headline = isHealthy ? 'READY TO RING' : 'ACTION REQUIRED';
        final detail = isHealthy
            ? 'Exact timing and notification delivery look healthy.'
            : 'Android still needs attention before alarm behavior is fully trustworthy.';

        return NeoPanel(
          color: NeoColors.panel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: NeoColors.ink, width: 2),
                    ),
                    child: const Icon(Icons.alarm, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alarm readiness',
                          style: theme.textTheme.labelMedium,
                        ),
                        Text(headline, style: theme.textTheme.headlineMedium),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                detail,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: NeoColors.subtext,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => NeoPanel(
        color: NeoColors.panel,
        child: Text(
          'Checking alarm readiness...',
          style: theme.textTheme.bodyMedium,
        ),
      ),
      error: (error, stackTrace) => NeoPanel(
        color: NeoColors.panel,
        child: Text('$error', style: theme.textTheme.bodyMedium),
      ),
    );
  }
}

class _DeviceDiagnosticsSection extends StatelessWidget {
  const _DeviceDiagnosticsSection({
    required this.status,
    required this.onRequestExactAlarmAccess,
    required this.onRequestNotificationAccess,
    required this.onRequestBatteryOptimizationExemption,
    required this.onRequestCameraPermission,
    required this.onRequestActivityRecognitionPermission,
  });

  final AsyncValue<AlarmEngineStatus> status;
  final VoidCallback onRequestExactAlarmAccess;
  final VoidCallback onRequestNotificationAccess;
  final VoidCallback onRequestBatteryOptimizationExemption;
  final VoidCallback onRequestCameraPermission;
  final VoidCallback onRequestActivityRecognitionPermission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NeoPanel(
      color: NeoColors.warm,
      child: status.when(
        data: (status) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NeoSectionTitle(
                title: 'Device readiness',
                subtitle:
                    'Exact alarms, notifications, battery behavior, camera access, and step tracking.',
              ),
              const SizedBox(height: 18),
              _DiagnosticTile(
                icon: Icons.alarm_on,
                title: 'Exact alarm status',
                statusLabel: status.canScheduleExactAlarms ? 'Allowed' : 'Fix',
                detail: status.canScheduleExactAlarms
                    ? 'Precise wake-up timing is available.'
                    : 'Precise wake-up timing is blocked until exact-alarm access is granted.',
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
              _DiagnosticTile(
                icon: Icons.notifications_active,
                title: 'Notification status',
                statusLabel: status.notificationsEnabled ? 'Ready' : 'Fix',
                detail: status.notificationsEnabled
                    ? 'Alarm notifications are allowed.'
                    : 'Foreground alarm notifications are blocked.',
                accent: status.notificationsEnabled
                    ? NeoColors.success
                    : NeoColors.orange,
                actionLabel: status.notificationsEnabled ? 'Ready' : 'Allow',
                onAction: status.notificationsEnabled
                    ? null
                    : onRequestNotificationAccess,
              ),
              const SizedBox(height: 12),
              _DiagnosticTile(
                icon: Icons.battery_alert,
                title: 'Battery optimization',
                statusLabel: status.batteryOptimizationIgnored
                    ? 'Ignored'
                    : 'Fix',
                detail: status.batteryOptimizationIgnored
                    ? 'Background restrictions are relaxed.'
                    : 'Aggressive OEM battery rules may interrupt alarm behavior.',
                accent: status.batteryOptimizationIgnored
                    ? NeoColors.success
                    : NeoColors.orange,
                actionLabel: status.batteryOptimizationIgnored
                    ? 'Ready'
                    : 'Open settings',
                onAction: status.batteryOptimizationIgnored
                    ? null
                    : onRequestBatteryOptimizationExemption,
              ),
              const SizedBox(height: 12),
              _DiagnosticTile(
                icon: Icons.photo_camera,
                title: 'Camera readiness',
                statusLabel: !status.hasCamera
                    ? 'None'
                    : status.cameraPermissionGranted
                    ? 'Ready'
                    : 'Fix',
                detail: !status.hasCamera
                    ? 'Camera missions are unsupported on this device.'
                    : status.cameraPermissionGranted
                    ? 'QR mission prerequisites are satisfied.'
                    : 'Grant camera permission for the QR mission.',
                accent: !status.hasCamera
                    ? NeoColors.muted
                    : status.cameraReady
                    ? NeoColors.success
                    : NeoColors.orange,
                actionLabel:
                    (!status.hasCamera || status.cameraPermissionGranted)
                    ? 'Ready'
                    : 'Allow',
                onAction: (!status.hasCamera || status.cameraPermissionGranted)
                    ? null
                    : onRequestCameraPermission,
              ),
              const SizedBox(height: 12),
              _DiagnosticTile(
                icon: Icons.directions_walk,
                title: 'Steps mission',
                statusLabel: !status.hasStepSensor
                    ? 'None'
                    : status.activityRecognitionGranted
                    ? 'Ready'
                    : 'Fix',
                detail: !status.hasStepSensor
                    ? 'This phone does not expose a live step detector for interactive step missions.'
                    : status.activityRecognitionGranted
                    ? 'Step mission prerequisites are satisfied.'
                    : 'Grant or re-enable activity recognition. If Android stops prompting, the action below opens app settings.',
                accent: !status.hasStepSensor
                    ? NeoColors.muted
                    : status.stepsMissionReady
                    ? NeoColors.success
                    : NeoColors.orange,
                actionLabel:
                    (!status.hasStepSensor || status.activityRecognitionGranted)
                    ? 'Ready'
                    : 'Grant / re-enable',
                onAction:
                    (!status.hasStepSensor || status.activityRecognitionGranted)
                    ? null
                    : onRequestActivityRecognitionPermission,
              ),
              const SizedBox(height: 18),
              NeoPanel(
                color: NeoColors.panel,
                padding: const EdgeInsets.all(18),
                shadowOffset: const Offset(3, 3),
                borderWidth: 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'If any warning remains unresolved, assume mission reliability is still provisional.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: NeoColors.subtext,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => Text(
          'Loading device readiness checks...',
          style: theme.textTheme.bodyMedium,
        ),
        error: (error, stackTrace) =>
            Text('$error', style: theme.textTheme.bodyMedium),
      ),
    );
  }
}

class _DiagnosticTile extends StatelessWidget {
  const _DiagnosticTile({
    required this.icon,
    required this.title,
    required this.statusLabel,
    required this.detail,
    required this.accent,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String statusLabel;
  final String detail;
  final Color accent;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NeoPanel(
      color: NeoColors.panel,
      padding: const EdgeInsets.all(14),
      borderWidth: 2,
      shadowOffset: const Offset(3, 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent,
              border: Border.all(color: NeoColors.ink, width: 2),
            ),
            child: Icon(icon, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NeoColors.subtext,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              NeoPill(label: statusLabel, backgroundColor: accent),
              if (actionLabel != null) ...[
                const SizedBox(height: 10),
                NeoActionButton(
                  label: actionLabel!,
                  compact: true,
                  backgroundColor: onAction == null
                      ? NeoColors.muted
                      : NeoColors.primary,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
