package dev.alarmsoss.alarms_oss.alarmengine

import android.content.Context
import org.json.JSONObject

class RingSessionStore(context: Context) {
    private val prefs =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun get(): AlarmRingSession? {
        val raw = prefs.getString(KEY_ACTIVE_SESSION, null) ?: return null
        return runCatching { AlarmRingSession.fromJson(JSONObject(raw)) }.getOrNull()
    }

    fun put(session: AlarmRingSession) {
        prefs.edit().putString(KEY_ACTIVE_SESSION, session.toJson().toString()).apply()
    }

    fun clear() {
        prefs.edit().remove(KEY_ACTIVE_SESSION).apply()
    }

    companion object {
        private const val PREFS_NAME = "alarm_engine_store"
        private const val KEY_ACTIVE_SESSION = "active_ring_session"
    }
}
