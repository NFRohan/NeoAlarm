package dev.neoalarm.app.alarmengine

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import dev.neoalarm.app.MainActivity

class AlarmNotificationPublisher(private val context: Context) {
    private val notificationManager = context.getSystemService(NotificationManager::class.java)

    fun showTriggeredAlarm(record: AlarmRecord) {
        createChannelIfNeeded()

        val notification = Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(record.label.ifBlank { "Alarm fired" })
            .setContentText("The scheduled alarm fired. Ringing service work starts in Sprint 3.")
            .setContentIntent(
                PendingIntent.getActivity(
                    context,
                    record.id.hashCode(),
                    Intent()
                        .setClass(context, MainActivity::class.java)
                        .setPackage(context.packageName)
                        .apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            .setAutoCancel(true)
            .build()

        try {
            notificationManager.notify(record.id.hashCode(), notification)
        } catch (error: SecurityException) {
            Log.w(TAG, "Notification permission missing for triggered alarm.", error)
        }
    }

    private fun createChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Alarm events",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Alarm fire and scheduling diagnostics."
        }

        notificationManager.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_ID = "alarm_events"
        private const val TAG = "AlarmNotification"
    }
}

