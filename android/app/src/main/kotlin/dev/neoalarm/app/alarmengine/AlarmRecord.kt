package dev.neoalarm.app.alarmengine

import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

data class AlarmRecord(
    val id: String,
    val label: String,
    val hour: Int,
    val minute: Int,
    val timezoneId: String,
    val followsDeviceTimezone: Boolean = true,
    val enabled: Boolean,
    val weekdays: List<Int>,
    val triggerKind: AlarmTriggerKind = AlarmTriggerKind.TIME,
    val locationTrigger: LocationAlarmRecord? = null,
    val ringtoneId: String,
    val customToneId: String?,
    val volumeRampEnabled: Boolean,
    val extraLoudEnabled: Boolean,
    val snoozeDurationMinutes: Int,
    val maxSnoozes: Int,
    val mission: MissionSpec,
    val nextTriggerAtEpochMillis: Long?,
    val skippedOccurrenceLocalDate: String?,
) {
    fun toChannelMap(): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "label" to label,
            "hour" to hour,
            "minute" to minute,
            "timezoneId" to timezoneId,
            "followsDeviceTimezone" to followsDeviceTimezone,
            "enabled" to enabled,
            "weekdays" to weekdays,
            "triggerKind" to triggerKind.id,
            "locationTrigger" to locationTrigger?.toChannelMap(),
            "ringtoneId" to ringtoneId,
            "customToneId" to customToneId,
            "volumeRampEnabled" to volumeRampEnabled,
            "extraLoudEnabled" to extraLoudEnabled,
            "snoozeDurationMinutes" to snoozeDurationMinutes,
            "maxSnoozes" to maxSnoozes,
            "mission" to mission.toChannelMap(),
            "nextTriggerAtUtc" to nextTriggerAtEpochMillis?.let {
                Instant.ofEpochMilli(it).toString()
            },
            "skippedOccurrenceLocalDate" to skippedOccurrenceLocalDate,
        )
    }

    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("id", id)
            put("label", label)
            put("hour", hour)
            put("minute", minute)
            put("timezoneId", timezoneId)
            put("followsDeviceTimezone", followsDeviceTimezone)
            put("enabled", enabled)
            put("weekdays", JSONArray().apply { weekdays.forEach(::put) })
            put("triggerKind", triggerKind.id)
            put("locationTrigger", locationTrigger?.toJson())
            put("ringtoneId", ringtoneId)
            put("customToneId", customToneId)
            put("volumeRampEnabled", volumeRampEnabled)
            put("extraLoudEnabled", extraLoudEnabled)
            put("snoozeDurationMinutes", snoozeDurationMinutes)
            put("maxSnoozes", maxSnoozes)
            put("mission", mission.toJson())
            put("nextTriggerAtEpochMillis", nextTriggerAtEpochMillis)
            put("skippedOccurrenceLocalDate", skippedOccurrenceLocalDate)
        }
    }

    companion object {
        fun fromChannelMap(raw: Map<*, *>): AlarmRecord {
            val weekdaysRaw = raw["weekdays"] as? List<*> ?: emptyList<Any?>()

            return AlarmRecord(
                id = raw["id"] as String,
                label = ((raw["label"] as? String)?.trim()).takeUnless { it.isNullOrEmpty() } ?: "Alarm",
                hour = (raw["hour"] as Number).toInt(),
                minute = (raw["minute"] as Number).toInt(),
                timezoneId = raw["timezoneId"] as String,
                followsDeviceTimezone = raw["followsDeviceTimezone"] as? Boolean ?: true,
                enabled = raw["enabled"] as Boolean,
                weekdays = weekdaysRaw.mapNotNull { (it as? Number)?.toInt() }.sorted(),
                triggerKind = AlarmTriggerKind.fromId(raw["triggerKind"] as? String),
                locationTrigger = (raw["locationTrigger"] as? Map<*, *>)?.let(LocationAlarmRecord::fromChannelMap),
                ringtoneId = (raw["ringtoneId"] as? String) ?: "system_alarm",
                customToneId = (raw["customToneId"] as? String)?.takeUnless { it.isBlank() },
                volumeRampEnabled = raw["volumeRampEnabled"] as? Boolean ?: false,
                extraLoudEnabled = raw["extraLoudEnabled"] as? Boolean ?: false,
                snoozeDurationMinutes = (raw["snoozeDurationMinutes"] as Number).toInt(),
                maxSnoozes = (raw["maxSnoozes"] as Number).toInt(),
                mission = MissionSpec.fromChannelMap(
                    raw["mission"] as? Map<*, *>,
                    fallbackType = raw["missionType"] as? String,
                ),
                nextTriggerAtEpochMillis = when (val rawNextTrigger = raw["nextTriggerAtUtc"]) {
                    is String -> Instant.parse(rawNextTrigger).toEpochMilli()
                    else -> null
                },
                skippedOccurrenceLocalDate = raw["skippedOccurrenceLocalDate"] as? String,
            )
        }

        fun fromJson(json: JSONObject): AlarmRecord {
            val weekdaysJson = json.optJSONArray("weekdays") ?: JSONArray()
            val weekdays = buildList {
                for (index in 0 until weekdaysJson.length()) {
                    add(weekdaysJson.getInt(index))
                }
            }.sorted()

            val nextTrigger = if (json.has("nextTriggerAtEpochMillis") && !json.isNull("nextTriggerAtEpochMillis")) {
                json.getLong("nextTriggerAtEpochMillis")
            } else {
                null
            }

            return AlarmRecord(
                id = json.getString("id"),
                label = json.optString("label", "Alarm"),
                hour = json.getInt("hour"),
                minute = json.getInt("minute"),
                timezoneId = json.getString("timezoneId"),
                followsDeviceTimezone = json.optBoolean("followsDeviceTimezone", true),
                enabled = json.getBoolean("enabled"),
                weekdays = weekdays,
                triggerKind = AlarmTriggerKind.fromId(json.optString("triggerKind", AlarmTriggerKind.TIME.id)),
                locationTrigger = json.optJSONObject("locationTrigger")?.let(LocationAlarmRecord::fromJson),
                ringtoneId = json.optString("ringtoneId", "system_alarm"),
                customToneId = json.optString("customToneId").takeUnless { it.isBlank() },
                volumeRampEnabled = json.optBoolean("volumeRampEnabled", false),
                extraLoudEnabled = json.optBoolean("extraLoudEnabled", false),
                snoozeDurationMinutes = json.optInt("snoozeDurationMinutes", 9),
                maxSnoozes = json.optInt("maxSnoozes", 3),
                mission = MissionSpec.fromJson(
                    json.optJSONObject("mission"),
                    fallbackType = json.optString("missionType", MissionSpec.TYPE_NONE),
                ),
                nextTriggerAtEpochMillis = nextTrigger,
                skippedOccurrenceLocalDate = json.optString("skippedOccurrenceLocalDate").takeUnless { it.isBlank() },
            )
        }
    }
}

