package dev.neoalarm.app.alarmengine

import org.json.JSONObject
import java.time.Instant

data class LocationAlarmRecord(
    val label: String,
    val latitude: Double,
    val longitude: Double,
    val radiusMeters: Int,
    val health: LocationAlarmHealth = LocationAlarmHealth.HEALTHY,
    val geofenceId: String? = null,
    val registeredAtEpochMillis: Long? = null,
    val lastTransitionAtEpochMillis: Long? = null,
    val approachState: LocationAlarmApproachState = LocationAlarmApproachState.IDLE,
    val approachEnteredAtEpochMillis: Long? = null,
) {
    fun toChannelMap(): Map<String, Any?> {
        return mapOf(
            "label" to label,
            "latitude" to latitude,
            "longitude" to longitude,
            "radiusMeters" to radiusMeters,
            "health" to health.id,
            "geofenceId" to geofenceId,
            "registeredAtUtc" to registeredAtEpochMillis?.let(Instant::ofEpochMilli)?.toString(),
            "lastTransitionAtUtc" to lastTransitionAtEpochMillis?.let(Instant::ofEpochMilli)?.toString(),
            "approachState" to approachState.id,
            "approachEnteredAtUtc" to approachEnteredAtEpochMillis?.let(Instant::ofEpochMilli)?.toString(),
        )
    }

    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("label", label)
            put("latitude", latitude)
            put("longitude", longitude)
            put("radiusMeters", radiusMeters)
            put("health", health.id)
            put("geofenceId", geofenceId)
            put("registeredAtEpochMillis", registeredAtEpochMillis)
            put("lastTransitionAtEpochMillis", lastTransitionAtEpochMillis)
            put("approachState", approachState.id)
            put("approachEnteredAtEpochMillis", approachEnteredAtEpochMillis)
        }
    }

    companion object {
        fun fromChannelMap(raw: Map<*, *>): LocationAlarmRecord {
            return LocationAlarmRecord(
                label = ((raw["label"] as? String)?.trim()).takeUnless { it.isNullOrEmpty() } ?: "Destination",
                latitude = (raw["latitude"] as Number).toDouble(),
                longitude = (raw["longitude"] as Number).toDouble(),
                radiusMeters = (raw["radiusMeters"] as Number).toInt(),
                health = LocationAlarmHealth.fromId(raw["health"] as? String),
                geofenceId = (raw["geofenceId"] as? String)?.takeUnless { it.isBlank() },
                registeredAtEpochMillis = when (val rawValue = raw["registeredAtUtc"]) {
                    is String -> Instant.parse(rawValue).toEpochMilli()
                    else -> null
                },
                lastTransitionAtEpochMillis = when (val rawValue = raw["lastTransitionAtUtc"]) {
                    is String -> Instant.parse(rawValue).toEpochMilli()
                    else -> null
                },
                approachState = LocationAlarmApproachState.fromId(raw["approachState"] as? String),
                approachEnteredAtEpochMillis = when (val rawValue = raw["approachEnteredAtUtc"]) {
                    is String -> Instant.parse(rawValue).toEpochMilli()
                    else -> null
                },
            )
        }

        fun fromJson(json: JSONObject): LocationAlarmRecord {
            val registeredAtEpochMillis = if (
                json.has("registeredAtEpochMillis") &&
                !json.isNull("registeredAtEpochMillis")
            ) {
                json.getLong("registeredAtEpochMillis")
            } else {
                null
            }
            val lastTransitionAtEpochMillis = if (
                json.has("lastTransitionAtEpochMillis") &&
                !json.isNull("lastTransitionAtEpochMillis")
            ) {
                json.getLong("lastTransitionAtEpochMillis")
            } else {
                null
            }
            val approachEnteredAtEpochMillis = if (
                json.has("approachEnteredAtEpochMillis") &&
                !json.isNull("approachEnteredAtEpochMillis")
            ) {
                json.getLong("approachEnteredAtEpochMillis")
            } else {
                null
            }

            return LocationAlarmRecord(
                label = json.optString("label", "Destination"),
                latitude = json.getDouble("latitude"),
                longitude = json.getDouble("longitude"),
                radiusMeters = json.getInt("radiusMeters"),
                health = LocationAlarmHealth.fromId(json.optString("health", LocationAlarmHealth.HEALTHY.id)),
                geofenceId = json.optString("geofenceId").takeUnless { it.isBlank() },
                registeredAtEpochMillis = registeredAtEpochMillis,
                lastTransitionAtEpochMillis = lastTransitionAtEpochMillis,
                approachState = LocationAlarmApproachState.fromId(json.optString("approachState")),
                approachEnteredAtEpochMillis = approachEnteredAtEpochMillis,
            )
        }
    }
}
