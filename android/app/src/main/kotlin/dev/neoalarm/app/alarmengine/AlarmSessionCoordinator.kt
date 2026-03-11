package dev.neoalarm.app.alarmengine

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

object AlarmSessionCoordinator {
    const val MISSION_INACTIVITY_TIMEOUT_MS = 30_000L

    fun activateMission(context: Context, session: AlarmRingSession): AlarmRingSession {
        val appContext = context.applicationContext
        val updatedSession = session.activateMission(
            System.currentTimeMillis() + MISSION_INACTIVITY_TIMEOUT_MS,
        )
        RingSessionStore(appContext).put(updatedSession)
        scheduleMissionTimeout(appContext, updatedSession)
        return updatedSession
    }

    fun extendMissionTimeout(
        context: Context,
        session: AlarmRingSession? = null,
    ): AlarmRingSession? {
        val appContext = context.applicationContext
        val store = RingSessionStore(appContext)
        val activeSession = session ?: store.get()?.takeIf(AlarmRingSession::isMissionActive)
        if (activeSession == null || !activeSession.isMissionActive) {
            return null
        }

        val updatedSession = activeSession.withMissionTimeout(
            System.currentTimeMillis() + MISSION_INACTIVITY_TIMEOUT_MS,
        )
        store.put(updatedSession)
        scheduleMissionTimeout(appContext, updatedSession)
        return updatedSession
    }

    fun scheduleSnooze(context: Context, session: AlarmRingSession) {
        val triggerAt = session.nextSnoozeAtEpochMillis ?: return
        alarmManager(context).setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAt,
            buildSnoozeOperation(context, session.alarmId),
        )
    }

    fun cancelSnooze(context: Context, alarmId: String) {
        alarmManager(context).cancel(buildSnoozeOperation(context, alarmId))
    }

    fun scheduleMissionTimeout(context: Context, session: AlarmRingSession) {
        val triggerAt = session.missionTimeoutAtEpochMillis
            ?: System.currentTimeMillis() + MISSION_INACTIVITY_TIMEOUT_MS
        alarmManager(context).setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAt,
            buildMissionTimeoutOperation(context, session.alarmId),
        )
    }

    fun cancelMissionTimeout(context: Context, alarmId: String) {
        alarmManager(context).cancel(buildMissionTimeoutOperation(context, alarmId))
    }

    private fun alarmManager(context: Context): AlarmManager {
        return context.applicationContext.getSystemService(AlarmManager::class.java)
    }

    private fun buildSnoozeOperation(context: Context, alarmId: String): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra(AlarmReceiver.EXTRA_ALARM_ID, alarmId)
            putExtra(AlarmReceiver.EXTRA_IS_SNOOZE, true)
        }

        return PendingIntent.getBroadcast(
            context,
            "$alarmId:snooze".hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun buildMissionTimeoutOperation(context: Context, alarmId: String): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra(AlarmReceiver.EXTRA_ALARM_ID, alarmId)
            putExtra(AlarmReceiver.EXTRA_IS_MISSION_TIMEOUT, true)
        }

        return PendingIntent.getBroadcast(
            context,
            "$alarmId:mission_timeout".hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
