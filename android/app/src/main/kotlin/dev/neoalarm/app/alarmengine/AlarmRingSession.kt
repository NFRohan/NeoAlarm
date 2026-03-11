package dev.neoalarm.app.alarmengine

import org.json.JSONObject
import java.time.Instant
import java.util.UUID

data class AlarmRingSession(
    val sessionId: String,
    val alarmId: String,
    val alarmLabel: String,
    val hour: Int,
    val minute: Int,
    val state: String,
    val mission: AlarmMissionRuntime,
    val startedAtEpochMillis: Long,
    val snoozeCount: Int,
    val maxSnoozes: Int,
    val snoozeDurationMinutes: Int,
    val nextSnoozeAtEpochMillis: Long?,
    val missionTimeoutAtEpochMillis: Long?,
) {
    fun toChannelMap(): Map<String, Any?> {
        return mapOf(
            "sessionId" to sessionId,
            "alarmId" to alarmId,
            "alarmLabel" to alarmLabel,
            "hour" to hour,
            "minute" to minute,
            "state" to state,
            "mission" to mission.toChannelMap(),
            "startedAtUtc" to Instant.ofEpochMilli(startedAtEpochMillis).toString(),
            "snoozeCount" to snoozeCount,
            "maxSnoozes" to maxSnoozes,
            "snoozeDurationMinutes" to snoozeDurationMinutes,
            "missionTimeoutAtUtc" to missionTimeoutAtEpochMillis?.let {
                Instant.ofEpochMilli(it).toString()
            },
        )
    }

    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("sessionId", sessionId)
            put("alarmId", alarmId)
            put("alarmLabel", alarmLabel)
            put("hour", hour)
            put("minute", minute)
            put("state", state)
            put("mission", mission.toJson())
            put("startedAtEpochMillis", startedAtEpochMillis)
            put("snoozeCount", snoozeCount)
            put("maxSnoozes", maxSnoozes)
            put("snoozeDurationMinutes", snoozeDurationMinutes)
            put("nextSnoozeAtEpochMillis", nextSnoozeAtEpochMillis)
            put("missionTimeoutAtEpochMillis", missionTimeoutAtEpochMillis)
        }
    }

    val isRinging: Boolean
        get() = state == STATE_RINGING

    val isMissionActive: Boolean
        get() = state == STATE_MISSION_ACTIVE

    val isActive: Boolean
        get() = isRinging || isMissionActive

    val canSnooze: Boolean
        get() = snoozeCount < maxSnoozes

    val isSnoozed: Boolean
        get() = state == STATE_SNOOZED

    fun resumeRinging(nowEpochMillis: Long = System.currentTimeMillis()): AlarmRingSession {
        return copy(
            state = STATE_RINGING,
            startedAtEpochMillis = nowEpochMillis,
            nextSnoozeAtEpochMillis = null,
            missionTimeoutAtEpochMillis = null,
        )
    }

    fun activateMission(missionTimeoutAtEpochMillis: Long): AlarmRingSession {
        return copy(
            state = STATE_MISSION_ACTIVE,
            missionTimeoutAtEpochMillis = missionTimeoutAtEpochMillis,
        )
    }

    fun preparedForPreemption(): AlarmRingSession {
        if (!isActive) {
            return this
        }

        return copy(
            state = STATE_RINGING,
            missionTimeoutAtEpochMillis = null,
        )
    }

    fun snoozedUntil(triggerAtEpochMillis: Long): AlarmRingSession {
        return copy(
            state = STATE_SNOOZED,
            snoozeCount = snoozeCount + 1,
            nextSnoozeAtEpochMillis = triggerAtEpochMillis,
            missionTimeoutAtEpochMillis = null,
        )
    }

    fun withMission(updatedMission: AlarmMissionRuntime): AlarmRingSession {
        return copy(mission = updatedMission)
    }

    fun withMissionTimeout(triggerAtEpochMillis: Long): AlarmRingSession {
        return copy(missionTimeoutAtEpochMillis = triggerAtEpochMillis)
    }

    companion object {
        const val STATE_RINGING = "ringing"
        const val STATE_MISSION_ACTIVE = "mission_active"
        const val STATE_SNOOZED = "snoozed"

        fun create(record: AlarmRecord): AlarmRingSession {
            return AlarmRingSession(
                sessionId = UUID.randomUUID().toString(),
                alarmId = record.id,
                alarmLabel = record.label,
                hour = record.hour,
                minute = record.minute,
                state = STATE_RINGING,
                mission = AlarmMissionRuntime.create(record.mission),
                startedAtEpochMillis = System.currentTimeMillis(),
                snoozeCount = 0,
                maxSnoozes = record.maxSnoozes,
                snoozeDurationMinutes = record.snoozeDurationMinutes,
                nextSnoozeAtEpochMillis = null,
                missionTimeoutAtEpochMillis = null,
            )
        }

        fun fromJson(json: JSONObject): AlarmRingSession {
            val nextSnoozeAt = if (json.has("nextSnoozeAtEpochMillis") &&
                !json.isNull("nextSnoozeAtEpochMillis")
            ) {
                json.getLong("nextSnoozeAtEpochMillis")
            } else {
                null
            }
            val missionTimeoutAt = if (json.has("missionTimeoutAtEpochMillis") &&
                !json.isNull("missionTimeoutAtEpochMillis")
            ) {
                json.getLong("missionTimeoutAtEpochMillis")
            } else {
                null
            }

            return AlarmRingSession(
                sessionId = json.getString("sessionId"),
                alarmId = json.getString("alarmId"),
                alarmLabel = json.optString("alarmLabel", "Alarm"),
                hour = json.optInt("hour", 0),
                minute = json.optInt("minute", 0),
                state = json.optString("state", STATE_RINGING),
                mission = AlarmMissionRuntime.fromJson(
                    json.optJSONObject("mission") ?: JSONObject().apply {
                        put("type", MissionSpec.TYPE_NONE)
                    },
                ),
                startedAtEpochMillis = json.getLong("startedAtEpochMillis"),
                snoozeCount = json.optInt("snoozeCount", 0),
                maxSnoozes = json.optInt("maxSnoozes", 3),
                snoozeDurationMinutes = json.optInt("snoozeDurationMinutes", 9),
                nextSnoozeAtEpochMillis = nextSnoozeAt,
                missionTimeoutAtEpochMillis = missionTimeoutAt,
            )
        }
    }
}

