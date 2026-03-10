package dev.alarmsoss.alarms_oss.alarmengine

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AlarmScheduler(context, AlarmStore(context)).rescheduleAll()
    }
}
