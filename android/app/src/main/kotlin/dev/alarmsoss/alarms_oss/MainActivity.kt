package dev.alarmsoss.alarms_oss

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import dev.alarmsoss.alarms_oss.alarmengine.AlarmEngineMethodCallHandler
import dev.alarmsoss.alarms_oss.alarmengine.AlarmRingingService
import dev.alarmsoss.alarms_oss.alarmengine.RingSessionStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.alarmsoss.alarm_engine",
        ).setMethodCallHandler(
            AlarmEngineMethodCallHandler(
                context = applicationContext,
                activity = this,
            ),
        )
    }

    private fun syncAlarmWindowState() {
        val hasActiveAlarm = RingSessionStore(applicationContext).get()?.isRinging == true
        val requestedAlarmUi =
            intent?.action == AlarmRingingService.ACTION_SHOW_ACTIVE_ALARM || hasActiveAlarm

        setShowWhenLocked(requestedAlarmUi)
        setTurnScreenOn(requestedAlarmUi)

        if (requestedAlarmUi) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}
