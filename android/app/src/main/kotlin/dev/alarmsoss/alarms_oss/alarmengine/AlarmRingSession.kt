package dev.alarmsoss.alarms_oss.alarmengine

import org.json.JSONObject
import java.time.Instant
import java.util.UUID

data class AlarmRingSession(
    val sessionId: String,
    val alarmId: String,
    val alarmLabel: String,
    val hour: Int,
    val minute: Int,
    val missionType: String,
    val startedAtEpochMillis: Long,
    val snoozeCount: Int,
    val maxSnoozes: Int,
) {
    fun toChannelMap(): Map<String, Any> {
        return mapOf(
            "sessionId" to sessionId,
            "alarmId" to alarmId,
            "alarmLabel" to alarmLabel,
            "hour" to hour,
            "minute" to minute,
            "missionType" to missionType,
            "startedAtUtc" to Instant.ofEpochMilli(startedAtEpochMillis).toString(),
            "snoozeCount" to snoozeCount,
            "maxSnoozes" to maxSnoozes,
        )
    }

    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("sessionId", sessionId)
            put("alarmId", alarmId)
            put("alarmLabel", alarmLabel)
            put("hour", hour)
            put("minute", minute)
            put("missionType", missionType)
            put("startedAtEpochMillis", startedAtEpochMillis)
            put("snoozeCount", snoozeCount)
            put("maxSnoozes", maxSnoozes)
        }
    }

    companion object {
        fun create(record: AlarmRecord): AlarmRingSession {
            return AlarmRingSession(
                sessionId = UUID.randomUUID().toString(),
                alarmId = record.id,
                alarmLabel = record.label,
                hour = record.hour,
                minute = record.minute,
                missionType = record.missionType,
                startedAtEpochMillis = System.currentTimeMillis(),
                snoozeCount = 0,
                maxSnoozes = record.maxSnoozes,
            )
        }

        fun fromJson(json: JSONObject): AlarmRingSession {
            return AlarmRingSession(
                sessionId = json.getString("sessionId"),
                alarmId = json.getString("alarmId"),
                alarmLabel = json.optString("alarmLabel", "Alarm"),
                hour = json.optInt("hour", 0),
                minute = json.optInt("minute", 0),
                missionType = json.optString("missionType", "none"),
                startedAtEpochMillis = json.getLong("startedAtEpochMillis"),
                snoozeCount = json.optInt("snoozeCount", 0),
                maxSnoozes = json.optInt("maxSnoozes", 3),
            )
        }
    }
}
