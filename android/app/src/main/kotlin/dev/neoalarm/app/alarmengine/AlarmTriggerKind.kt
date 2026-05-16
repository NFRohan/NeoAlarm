package dev.neoalarm.app.alarmengine

enum class AlarmTriggerKind(val id: String) {
    TIME("time"),
    LOCATION("location");

    companion object {
        fun fromId(value: String?): AlarmTriggerKind {
            return entries.firstOrNull { it.id == value } ?: TIME
        }
    }
}
