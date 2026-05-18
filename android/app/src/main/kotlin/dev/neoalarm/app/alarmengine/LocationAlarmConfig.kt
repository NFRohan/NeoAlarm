package dev.neoalarm.app.alarmengine

import android.location.Location

internal object LocationAlarmConfig {
    const val INITIAL_RETRY_DELAY_MS = 30_000L
    const val MAX_RETRY_DELAY_MS = 15 * 60 * 1000L
    const val DUPLICATE_TRIGGER_COOLDOWN_MS = 60_000L
    const val OUTER_RADIUS_MULTIPLIER = 3
    const val PASSIVE_LOCATION_UPDATE_INTERVAL_MS = 30_000L
    const val PLAY_SERVICES_TASK_TIMEOUT_MS = 8_000L
    const val CURRENT_LOCATION_TASK_TIMEOUT_MS = 10_000L
    const val LOCATION_GEOFENCE_PENDING_INTENT_REQUEST_CODE = 42042
    const val LOCATION_PASSIVE_UPDATES_PENDING_INTENT_REQUEST_CODE = 42043
    const val LOCATION_REARM_RETRY_PENDING_INTENT_REQUEST_CODE = 42044
    const val INNER_GEOFENCE_ID_PREFIX = "location_alarm:"
    const val OUTER_GEOFENCE_ID_PREFIX = "location_alarm_outer:"

    fun geofenceIdFor(alarmId: String): String = "$INNER_GEOFENCE_ID_PREFIX$alarmId"

    fun outerGeofenceIdFor(alarmId: String): String = "$OUTER_GEOFENCE_ID_PREFIX$alarmId"

    fun outerRadiusMetersFor(trigger: LocationAlarmRecord): Int {
        return trigger.radiusMeters * OUTER_RADIUS_MULTIPLIER
    }

    fun retryDelayMillisFor(retryCount: Int): Long {
        val exponent = (retryCount - 1).coerceAtLeast(0)
        val multiplier = 1L shl exponent
        return (INITIAL_RETRY_DELAY_MS * multiplier).coerceAtMost(MAX_RETRY_DELAY_MS)
    }
}

internal fun clearLocationAlarmRegistration(
    trigger: LocationAlarmRecord,
): LocationAlarmRecord {
    return trigger.copy(
        geofenceId = null,
        registeredAtEpochMillis = null,
        approachState = LocationAlarmApproachState.IDLE,
        approachEnteredAtEpochMillis = null,
        rearmRetryCount = 0,
        nextRearmRetryAtEpochMillis = null,
    )
}

internal fun Location.distanceToLocationTrigger(trigger: LocationAlarmRecord): Float {
    val target = Location("location_alarm_target").apply {
        latitude = trigger.latitude
        longitude = trigger.longitude
    }

    return distanceTo(target)
}
