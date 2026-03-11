import 'dart:async';

import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:neoalarm/src/features/alarms/domain/active_alarm_session.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_mission.dart';
import 'package:neoalarm/src/platform/missions/mission_driver.dart';
import 'package:neoalarm/src/platform/vision/vision_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QrMissionDriver implements MissionDriver {
  const QrMissionDriver();

  @override
  AlarmMissionType get type => AlarmMissionType.qr;

  @override
  Widget buildRunner({
    required BuildContext context,
    required ActiveAlarmSession session,
    required MissionActionCallbacks actions,
  }) {
    return QrMissionRunner(session: session, actions: actions);
  }
}

class QrMissionRunner extends ConsumerStatefulWidget {
  const QrMissionRunner({
    required this.session,
    required this.actions,
    super.key,
  });

  final ActiveAlarmSession session;
  final MissionActionCallbacks actions;

  @override
  ConsumerState<QrMissionRunner> createState() => _QrMissionRunnerState();
}

class _QrMissionRunnerState extends ConsumerState<QrMissionRunner>
    with WidgetsBindingObserver {
  StreamSubscription<VisionEvent>? _eventSubscription;
  String? _errorCode;
  String? _errorMessage;
  String? _lastMismatchValue;
  String? _activeTargetValue;
  bool _scannerReady = false;

  String? get _targetValue => widget.session.mission.spec.qrTargetValue;

  QrProgressSnapshot? get _qrProgress => widget.session.mission.qrProgress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eventSubscription = ref
        .read(visionControllerProvider)
        .events()
        .listen(_handleVisionEvent);
    unawaited(_startMissionSession());
  }

  @override
  void didUpdateWidget(covariant QrMissionRunner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.sessionId != oldWidget.session.sessionId ||
        _targetValue != oldWidget.session.mission.spec.qrTargetValue) {
      unawaited(_startMissionSession());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSubscription?.cancel();
    unawaited(ref.read(visionControllerProvider).stopSession());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumeMissionSession());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qrProgress = _qrProgress;

    if (qrProgress == null) {
      return NeoPanel(
        child: Text(
          'QR mission data is unavailable for this session.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    if (qrProgress.isTargetMissing || _targetValue == null) {
      return NeoPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('QR target missing', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text(
              'This alarm was configured without a saved QR target, so the mission cannot be completed.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (qrProgress.isPermissionBlocked ||
        _errorCode == 'camera_permission_missing') {
      return NeoPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Camera access required',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ??
                  'Camera permission was removed. Grant it again to continue scanning the target QR code.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            NeoActionButton(
              label: 'Grant camera access',
              expand: true,
              backgroundColor: NeoColors.cyan,
              onPressed: () async {
                await widget.actions.requestCameraPermission();
                if (!mounted) {
                  return;
                }
                await _resumeMissionSession();
              },
            ),
          ],
        ),
      );
    }

    if (qrProgress.isUnsupported || _errorCode == 'camera_unavailable') {
      return NeoPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Camera unavailable', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text(
              _errorMessage ??
                  'This device is not reporting a usable camera for the QR mission.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return NeoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scan saved QR target', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            _lastMismatchValue == null
                ? 'Point the camera at the saved QR code to dismiss the alarm.'
                : 'Wrong QR code. Scan the saved target instead.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 1,
            child: NeoPanel(
              color: NeoColors.primary,
              padding: const EdgeInsets.all(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const VisionPreviewSurface(),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          border: Border.all(color: NeoColors.panel, width: 4),
                        ),
                      ),
                    ),
                  ),
                  if (!_scannerReady)
                    Container(
                      color: NeoColors.ink.withValues(alpha: 0.12),
                      alignment: Alignment.center,
                      child: Text(
                        'Starting camera...',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          NeoPanel(
            color: _lastMismatchValue == null
                ? NeoColors.warm
                : NeoColors.orange,
            borderWidth: 2,
            shadowOffset: const Offset(3, 3),
            child: Text(
              _lastMismatchValue == null
                  ? 'Waiting for a QR code...'
                  : 'Last code did not match: $_lastMismatchValue',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startMissionSession() async {
    final targetValue = _targetValue;
    if (targetValue == null) {
      _activeTargetValue = null;
      await ref.read(visionControllerProvider).stopSession();
      return;
    }

    final alreadyTrackingTarget =
        _activeTargetValue == targetValue &&
        _scannerReady &&
        _errorCode == null;
    if (alreadyTrackingTarget) {
      return;
    }

    setState(() {
      _activeTargetValue = targetValue;
      _scannerReady = false;
      _errorCode = null;
      _errorMessage = null;
      _lastMismatchValue = null;
    });

    try {
      await ref
          .read(visionControllerProvider)
          .startQrMission(targetValue: targetValue);
      if (!mounted) {
        return;
      }
      widget.actions.refreshSession();
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _activeTargetValue = targetValue;
        _scannerReady = false;
        _errorCode = error.code;
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _resumeMissionSession() async {
    await _startMissionSession();
    if (!mounted) {
      return;
    }
    widget.actions.refreshSession();
  }

  void _handleVisionEvent(VisionEvent event) {
    final acceptsEvent =
        event.mode == VisionSessionMode.qrMission ||
        event.type == VisionEventType.error;

    if (!mounted || !acceptsEvent) {
      return;
    }

    switch (event.type) {
      case VisionEventType.ready:
        setState(() {
          _activeTargetValue = _targetValue;
          _scannerReady = true;
          _errorCode = null;
          _errorMessage = null;
        });
        widget.actions.refreshSession();
        return;
      case VisionEventType.qrMismatch:
        setState(() {
          _activeTargetValue = _targetValue;
          _scannerReady = true;
          _lastMismatchValue = event.rawValue;
          _errorCode = null;
          _errorMessage = null;
        });
        widget.actions.refreshSession();
        return;
      case VisionEventType.qrMatched:
        widget.actions.refreshSession();
        return;
      case VisionEventType.error:
        setState(() {
          _scannerReady = false;
          _errorCode = event.code;
          _errorMessage = event.message;
        });
        widget.actions.refreshSession();
        return;
      case VisionEventType.qrDetected:
        return;
    }
  }
}
