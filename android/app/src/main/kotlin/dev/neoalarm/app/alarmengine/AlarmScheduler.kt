package dev.neoalarm.app.alarmengine

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import dev.neoalarm.app.MainActivity
import java.time.Instant
import java.time.LocalDate
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
        return upsert(
            current.copy(
                enabled = enabled,
                skippedOccurrenceLocalDate = if (enabled) current.skippedOccurrenceLocalDate else null,
            ),
        )
    }

    fun skipNextOccurrence(id: String): AlarmRecord {
        val current = store.get(id) ?: throw IllegalArgumentException("Alarm not found: $id")
        if (current.weekdays.isEmpty()) {
            throw IllegalStateException("Skip next is only available for repeating alarms.")
        }

        val nextOccurrence = computeNextTrigger(current.copy(skippedOccurrenceLocalDate = null))
        val skippedDate = nextOccurrence.localDate
            ?: throw IllegalStateException("Unable to determine the next occurrence to skip.")

        return upsert(current.copy(skippedOccurrenceLocalDate = skippedDate.toString()))
    }

    fun clearSkippedOccurrence(id: String): AlarmRecord {
        val current = store.get(id) ?: throw IllegalArgumentException("Alarm not found: $id")
        return upsert(current.copy(skippedOccurrenceLocalDate = null))
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
            current.copy(
                enabled = false,
                nextTriggerAtEpochMillis = null,
                skippedOccurrenceLocalDate = null,
            )
        } else {
            val nextTrigger = computeNextTrigger(current, Instant.now().plusSeconds(1))
            current.copy(
                nextTriggerAtEpochMillis = nextTrigger.epochMillis,
                skippedOccurrenceLocalDate = nextTrigger.skippedOccurrenceLocalDate,
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

        val nextTrigger = computeNextTrigger(record)
        val updated = record.copy(
            nextTriggerAtEpochMillis = nextTrigger.epochMillis,
            skippedOccurrenceLocalDate = nextTrigger.skippedOccurrenceLocalDate,
        )

        if (nextTrigger.epochMillis == null) {
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
            Intent()
                .setClass(context, MainActivity::class.java)
                .setPackage(context.packageName)
                .apply {
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
        val intent = Intent()
            .setClass(context, AlarmReceiver::class.java)
            .setPackage(context.packageName)
            .apply {
            putExtra(AlarmReceiver.EXTRA_ALARM_ID, id)
        }

        return PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun computeNextTrigger(
        record: AlarmRecord,
        fromInstant: Instant = Instant.now(),
    ): NextTriggerResult {
        val zoneId = resolveZoneId(record.timezoneId)
        val now = ZonedDateTime.ofInstant(fromInstant, zoneId)
        val localTime = LocalTime.of(record.hour, record.minute)
        val skippedDate = record.skippedOccurrenceLocalDate?.let(::parseLocalDate)

        if (record.weekdays.isEmpty()) {
            var candidate = now.withHour(record.hour).withMinute(record.minute).withSecond(0).withNano(0)
            if (!candidate.isAfter(now)) {
                candidate = candidate.plusDays(1)
            }
            return NextTriggerResult(
                epochMillis = candidate.toInstant().toEpochMilli(),
                skippedOccurrenceLocalDate = null,
                localDate = candidate.toLocalDate(),
            )
        }

        for (offset in 0..14) {
            val date = now.toLocalDate().plusDays(offset.toLong())
            val weekday = date.dayOfWeek.value
            if (!record.weekdays.contains(weekday)) {
                continue
            }

            val candidate = date.atTime(localTime).atZone(zoneId)
            if (!candidate.isAfter(now)) {
                continue
            }

            if (skippedDate != null && date == skippedDate) {
                continue
            }

            val normalizedSkippedDate = skippedDate?.takeUnless { date.isAfter(it) }
            return NextTriggerResult(
                epochMillis = candidate.toInstant().toEpochMilli(),
                skippedOccurrenceLocalDate = normalizedSkippedDate?.toString(),
                localDate = date,
            )
        }

        return NextTriggerResult(epochMillis = null, skippedOccurrenceLocalDate = null, localDate = null)
    }

    private fun parseLocalDate(value: String): LocalDate? {
        return try {
            LocalDate.parse(value)
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveZoneId(timezoneId: String): ZoneId {
        return try {
            ZoneId.of(timezoneId)
        } catch (_: Exception) {
            ZoneId.systemDefault()
        }
    }

    private data class NextTriggerResult(
        val epochMillis: Long?,
        val skippedOccurrenceLocalDate: String?,
        val localDate: LocalDate?,
    )
}

class ExactAlarmPermissionException(message: String) : IllegalStateException(message)

