package dev.neoalarm.app.alarmengine

enum class LocationAlarmHealth(val id: String) {
    HEALTHY("healthy"),
    NO_FOREGROUND_PERMISSION("no_foreground_permission"),
    NO_BACKGROUND_PERMISSION("no_background_permission"),
    LOCATION_DISABLED("location_disabled"),
    GEOFENCE_NOT_REGISTERED("geofence_not_registered"),
    WAITING_FOR_EXIT("waiting_for_exit"),
    PLAY_SERVICES_UNAVAILABLE("play_services_unavailable"),
    BATTERY_RESTRICTED("battery_restricted"),
    LOW_LOCATION_CONFIDENCE("low_location_confidence");

    companion object {
        fun fromId(value: String?): LocationAlarmHealth {
            return entries.firstOrNull { it.id == value } ?: HEALTHY
        }
    }
}
