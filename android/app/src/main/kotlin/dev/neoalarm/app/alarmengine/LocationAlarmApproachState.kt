package dev.neoalarm.app.alarmengine

enum class LocationAlarmApproachState(val id: String) {
    IDLE("idle"),
    APPROACHING("approaching");

    companion object {
        fun fromId(raw: String?): LocationAlarmApproachState {
            return entries.firstOrNull { it.id == raw } ?: IDLE
        }
    }
}
