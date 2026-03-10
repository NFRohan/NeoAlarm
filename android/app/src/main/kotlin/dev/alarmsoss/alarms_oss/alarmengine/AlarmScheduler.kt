package dev.alarmsoss.alarms_oss.alarmengine

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import dev.alarmsoss.alarms_oss.MainActivity
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime

class AlarmScheduler(
    private val context: Context,
    private val store: AlarmStore,
) {
    private val alarmManager = context.getSystemService(AlarmManager::class.java)

    fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    fun upsert(record: AlarmRecord): AlarmRecord {
        val updated = rescheduleRecord(record)
        store.upsert(updated)
        return updated
    }

    fun updateEnabled(id: String, enabled: Boolean): AlarmRecord {
        val current = store.get(id) ?: throw IllegalArgumentException("Alarm not found: $id")
        return upsert(current.copy(enabled = enabled))
    }

    fun delete(id: String) {
        cancel(id)
        store.delete(id)
    }

    fun rescheduleAll() {
        val updated = store.getAll().map(::rescheduleRecord)
        store.replaceAll(updated)
    }

    fun handleAlarmTriggered(id: String): AlarmRecord? {
        val current = store.get(id) ?: return null
        val updated = if (current.weekdays.isEmpty()) {
            current.copy(enabled = false, nextTriggerAtEpochMillis = null)
        } else {
            current.copy(
                nextTriggerAtEpochMillis = computeNextTriggerEpochMillis(
                    current,
                    Instant.now().plusSeconds(1),
                ),
            )
        }

        if (updated.enabled && updated.nextTriggerAtEpochMillis != null) {
            schedule(updated)
        } else {
            cancel(updated.id)
        }

        store.upsert(updated)
        return updated
    }

    private fun rescheduleRecord(record: AlarmRecord): AlarmRecord {
        if (!record.enabled) {
            cancel(record.id)
            return record.copy(nextTriggerAtEpochMillis = null)
        }

        if (!canScheduleExactAlarms()) {
            throw ExactAlarmPermissionException(
                "Android exact alarm access is required before enabled alarms can be scheduled.",
            )
        }

        val nextTriggerAtEpochMillis = computeNextTriggerEpochMillis(record)
        val updated = record.copy(nextTriggerAtEpochMillis = nextTriggerAtEpochMillis)

        if (nextTriggerAtEpochMillis == null) {
            cancel(record.id)
        } else {
            schedule(updated)
        }

        return updated
    }

    private fun schedule(record: AlarmRecord) {
        val triggerAtMillis = record.nextTriggerAtEpochMillis ?: return
        val operation = buildAlarmOperation(record.id)
        val showIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        alarmManager.setAlarmClock(
            AlarmManager.AlarmClockInfo(triggerAtMillis, showIntent),
            operation,
        )
    }

    private fun cancel(id: String) {
        alarmManager.cancel(buildAlarmOperation(id))
    }

    private fun buildAlarmOperation(id: String): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra(AlarmReceiver.EXTRA_ALARM_ID, id)
        }

        return PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun computeNextTriggerEpochMillis(
        record: AlarmRecord,
        fromInstant: Instant = Instant.now(),
    ): Long? {
        val zoneId = resolveZoneId(record.timezoneId)
        val now = ZonedDateTime.ofInstant(fromInstant, zoneId)
        val localTime = LocalTime.of(record.hour, record.minute)

        if (record.weekdays.isEmpty()) {
            var candidate = now.withHour(record.hour).withMinute(record.minute).withSecond(0).withNano(0)
            if (!candidate.isAfter(now)) {
                candidate = candidate.plusDays(1)
            }
            return candidate.toInstant().toEpochMilli()
        }

        for (offset in 0..7) {
            val date = now.toLocalDate().plusDays(offset.toLong())
            val weekday = date.dayOfWeek.value
            if (!record.weekdays.contains(weekday)) {
                continue
            }

            val candidate = date.atTime(localTime).atZone(zoneId)
            if (candidate.isAfter(now)) {
                return candidate.toInstant().toEpochMilli()
            }
        }

        return null
    }

    private fun resolveZoneId(timezoneId: String): ZoneId {
        return try {
            ZoneId.of(timezoneId)
        } catch (_: Exception) {
            ZoneId.systemDefault()
        }
    }
}

class ExactAlarmPermissionException(message: String) : IllegalStateException(message)
