import 'dart:async';

import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:neoalarm/src/features/alarms/application/alarm_list_controller.dart';
import 'package:neoalarm/src/platform/vision/vision_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QrTargetCaptureScreen extends ConsumerStatefulWidget {
  const QrTargetCaptureScreen({super.key});

  @override
  ConsumerState<QrTargetCaptureScreen> createState() =>
      _QrTargetCaptureScreenState();
}

class _QrTargetCaptureScreenState extends ConsumerState<QrTargetCaptureScreen>
    with WidgetsBindingObserver {
  StreamSubscription<VisionEvent>? _eventSubscription;
  String? _detectedValue;
  String? _errorCode;
  String? _errorMessage;
  bool _scannerReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eventSubscription = ref
        .read(visionControllerProvider)
        .events()
        .listen(_handleVisionEvent);
    unawaited(_startRegistration());
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
      unawaited(_startRegistration());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryForeground = NeoColors.foregroundOn(NeoColors.primary);
    final isPermissionBlocked = _errorCode == 'camera_permission_missing';
    final isUnsupported = _errorCode == 'camera_unavailable';

    return Scaffold(
      backgroundColor: NeoColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              Row(
                children: [
                  NeoSquareIconButton(
                    icon: Icons.arrow_back,
                    backgroundColor: NeoColors.warm,
                    size: 48,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'SCAN TARGET QR',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: primaryForeground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isPermissionBlocked || isUnsupported)
                NeoPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPermissionBlocked
                            ? 'Camera access required'
                            : 'Camera unavailable',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage ??
                            'The QR target scanner cannot start right now.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (isPermissionBlocked) ...[
                        const SizedBox(height: 18),
                        NeoActionButton(
                          label: 'Grant camera access',
                          expand: true,
                          backgroundColor: NeoColors.cyan,
                          onPressed: () async {
                            await ref
                                .read(alarmRepositoryProvider)
                                .requestCameraPermission();
                            if (!mounted) {
                              return;
                            }
                            await _startRegistration();
                          },
                        ),
                      ],
                    ],
                  ),
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: NeoPanel(
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
                                      border: Border.all(
                                        color: NeoColors.panel,
                                        width: 4,
                                      ),
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
                      const SizedBox(height: 16),
                      NeoPanel(
                        color: NeoColors.warm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _detectedValue == null
                                  ? 'Point the camera at the QR code you want this alarm to require.'
                                  : 'Detected code:',
                              style: theme.textTheme.bodyMedium,
                            ),
                            if (_detectedValue != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _detectedValue!,
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                            const SizedBox(height: 16),
                            NeoActionButton(
                              label: _detectedValue == null
                                  ? 'Waiting for QR code'
                                  : 'Use this code',
                              expand: true,
                              backgroundColor: NeoColors.cyan,
                              onPressed: _detectedValue == null
                                  ? null
                                  : () {
                                      Navigator.of(context).pop(_detectedValue);
                                    },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startRegistration() async {
    setState(() {
      _detectedValue = null;
      _errorCode = null;
      _errorMessage = null;
      _scannerReady = false;
    });

    try {
      await ref.read(visionControllerProvider).startQrRegistration();
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorCode = error.code;
        _errorMessage = error.message;
      });
    }
  }

  void _handleVisionEvent(VisionEvent event) {
    if (!mounted) {
      return;
    }

    switch (event.type) {
      case VisionEventType.ready:
        setState(() {
          _scannerReady = true;
          _errorCode = null;
          _errorMessage = null;
        });
        return;
      case VisionEventType.qrDetected:
        setState(() {
          _detectedValue = event.rawValue;
          _errorCode = null;
          _errorMessage = null;
          _scannerReady = true;
        });
        return;
      case VisionEventType.error:
        setState(() {
          _errorCode = event.code;
          _errorMessage = event.message;
          _scannerReady = false;
        });
        return;
      case VisionEventType.qrMatched:
      case VisionEventType.qrMismatch:
        return;
    }
  }
}
