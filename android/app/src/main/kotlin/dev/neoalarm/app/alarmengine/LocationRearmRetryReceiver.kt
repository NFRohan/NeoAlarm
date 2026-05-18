package dev.neoalarm.app.alarmengine

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class LocationRearmRetryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_LOCATION_REARM_RETRY) {
            return
        }

        val pendingResult = goAsync()
        Thread {
            try {
                val appContext = context.applicationContext
                LocationAlarmCoordinator(appContext, AlarmStore(appContext)).syncAll()
            } catch (error: Exception) {
                Log.e(logTag, "Location re-arm retry failed: ${error.message}", error)
            } finally {
                pendingResult.finish()
            }
        }.start()
    }

    companion object {
        private const val logTag = "NeoAlarmLocationRetry"
        const val ACTION_LOCATION_REARM_RETRY =
            "dev.neoalarm.app.action.LOCATION_REARM_RETRY"
    }
}
