package dev.neoalarm.app.alarmengine

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

class RingSessionStore(context: Context) {
    private val prefs =
        alarmEngineStorageContext(context)
            .getSharedPreferences(ALARM_ENGINE_PREFS_NAME, Context.MODE_PRIVATE)

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

    fun registerListener(
        onChanged: (AlarmRingSession?) -> Unit,
    ): SharedPreferences.OnSharedPreferenceChangeListener {
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == KEY_ACTIVE_SESSION) {
                onChanged(get())
            }
        }
        prefs.registerOnSharedPreferenceChangeListener(listener)
        return listener
    }

    fun unregisterListener(listener: SharedPreferences.OnSharedPreferenceChangeListener) {
        prefs.unregisterOnSharedPreferenceChangeListener(listener)
    }

    companion object {
        private const val KEY_ACTIVE_SESSION = "active_ring_session"
    }
}

