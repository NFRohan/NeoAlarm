package dev.neoalarm.app

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import dev.neoalarm.app.alarmengine.AlarmEngineMethodCallHandler
import dev.neoalarm.app.alarmengine.AlarmRingingService
import dev.neoalarm.app.alarmengine.ActiveSessionStreamHandler
import dev.neoalarm.app.alarmengine.RingSessionStore
import dev.neoalarm.app.vision.VisionMethodCallHandler
import dev.neoalarm.app.vision.VisionPreviewPlatformViewFactory
import dev.neoalarm.app.vision.VisionSessionManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var visionSessionManager: VisionSessionManager
    private lateinit var activeSessionStreamHandler: ActiveSessionStreamHandler

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        syncAlarmWindowState()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        syncAlarmWindowState()
    }

    override fun onResume() {
        super.onResume()
        syncAlarmWindowState()
    }

    override fun onDestroy() {
        if (::visionSessionManager.isInitialized) {
            visionSessionManager.dispose()
        }
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        visionSessionManager = VisionSessionManager(
            context = applicationContext,
            lifecycleOwner = this,
        )
        activeSessionStreamHandler = ActiveSessionStreamHandler(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.neoalarm.app.alarm_engine",
        ).setMethodCallHandler(
            AlarmEngineMethodCallHandler(
                context = applicationContext,
                activity = this,
            ),
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.neoalarm.app.vision",
        ).setMethodCallHandler(VisionMethodCallHandler(visionSessionManager))

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.neoalarm.app.alarm_engine/active_session",
        ).setStreamHandler(activeSessionStreamHandler)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.neoalarm.app.vision/events",
        ).setStreamHandler(visionSessionManager)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            "dev.neoalarm.app.vision/preview",
            VisionPreviewPlatformViewFactory(visionSessionManager),
        )
    }

    private fun syncAlarmWindowState() {
        val activeSession = RingSessionStore(applicationContext).get()
        val requestedAlarmUi = activeSession?.isActive == true

        setShowWhenLocked(requestedAlarmUi)
        setTurnScreenOn(requestedAlarmUi)

        if (requestedAlarmUi) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}

