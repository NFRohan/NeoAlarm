package dev.alarmsoss.alarms_oss.alarmengine

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val alarmId = intent.getStringExtra(EXTRA_ALARM_ID) ?: return
        val store = AlarmStore(context)
        val scheduler = AlarmScheduler(context, store)
        val triggered = scheduler.handleAlarmTriggered(alarmId) ?: return
        AlarmRingingService.start(context, triggered.id)
    }

    companion object {
        const val EXTRA_ALARM_ID = "alarm_id"
    }
}
