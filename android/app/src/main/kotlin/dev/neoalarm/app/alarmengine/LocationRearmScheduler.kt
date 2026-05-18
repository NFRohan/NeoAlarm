package dev.neoalarm.app.alarmengine

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

internal class LocationRearmScheduler(
    context: Context,
    private val store: AlarmStore,
) {
    private val appContext = context.applicationContext
    private val alarmManager = appContext.getSystemService(AlarmManager::class.java)

    fun sync() {
        val nextRetryAt = store.getAll()
            .asSequence()
            .filter { it.triggerKind == AlarmTriggerKind.LOCATION && it.enabled }
            .mapNotNull { record ->
                record.locationTrigger
                    ?.takeIf { it.health == LocationAlarmHealth.REARM_PENDING }
                    ?.nextRearmRetryAtEpochMillis
            }
            .minOrNull()

        val pendingIntent = deferredRearmPendingIntent()
        if (nextRetryAt == null) {
            alarmManager.cancel(pendingIntent)
            return
        }

        alarmManager.cancel(pendingIntent)
        alarmManager.set(
            AlarmManager.RTC_WAKEUP,
            nextRetryAt,
            pendingIntent,
        )
    }

    private fun deferredRearmPendingIntent(): PendingIntent {
        val intent = Intent(LocationRearmRetryReceiver.ACTION_LOCATION_REARM_RETRY)
            .setClass(appContext, LocationRearmRetryReceiver::class.java)
            .setPackage(appContext.packageName)

        return PendingIntent.getBroadcast(
            appContext,
            LocationAlarmConfig.LOCATION_REARM_RETRY_PENDING_INTENT_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
