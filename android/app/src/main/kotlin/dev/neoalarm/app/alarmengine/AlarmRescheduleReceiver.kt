package dev.neoalarm.app.alarmengine

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in ALLOWED_ACTIONS) {
            return
        }

        val pendingResult = goAsync()
        Thread {
            try {
                val appContext = context.applicationContext
                val store = AlarmStore(appContext)
                runCatching {
                    AlarmScheduler(appContext, store).rescheduleAll()
                }.onFailure { error ->
                    Log.e(logTag, "Time alarm reschedule failed: ${error.message}", error)
                }
                runCatching {
                    LocationAlarmCoordinator(appContext, store).syncAll()
                }.onFailure { error ->
                    Log.e(logTag, "Location alarm sync failed: ${error.message}", error)
                }
            } finally {
                pendingResult.finish()
            }
        }.start()
    }

    companion object {
        private const val logTag = "NeoAlarmReschedule"

        private val ALLOWED_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
        )
    }
}

