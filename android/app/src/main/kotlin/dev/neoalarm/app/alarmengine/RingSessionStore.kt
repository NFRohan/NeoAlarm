package dev.neoalarm.app.alarmengine

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

class RingSessionStore(context: Context) {
    private val prefs =
        alarmEngineStorageContext(context)
            .getSharedPreferences(ALARM_ENGINE_PREFS_NAME, Context.MODE_PRIVATE)

    fun get(): AlarmRingSession? {
        return getAll().lastOrNull(AlarmRingSession::isActive)
    }

    fun getAll(): List<AlarmRingSession> {
        val raw = prefs.getString(KEY_ACTIVE_SESSION, null) ?: return emptyList()
        return runCatching {
            val trimmed = raw.trim()
            if (trimmed.startsWith("[")) {
                parseArray(JSONArray(trimmed))
            } else {
                listOf(AlarmRingSession.fromJson(JSONObject(trimmed)))
            }
        }.getOrDefault(emptyList())
    }

    fun put(session: AlarmRingSession) {
        val updated = getAll().toMutableList()
        val existingIndex = updated.indexOfFirst { it.sessionId == session.sessionId }
        if (existingIndex >= 0) {
            updated[existingIndex] = session
        } else {
            updated.add(session)
        }
        putAll(updated)
    }

    fun putAll(sessions: List<AlarmRingSession>) {
        val encoded = JSONArray().apply {
            sessions.forEach { put(it.toJson()) }
        }
        prefs.edit().putString(KEY_ACTIVE_SESSION, encoded.toString()).apply()
    }

    fun remove(sessionId: String) {
        putAll(getAll().filterNot { it.sessionId == sessionId })
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

        private fun parseArray(array: JSONArray): List<AlarmRingSession> {
            return buildList {
                for (index in 0 until array.length()) {
                    val rawSession = array.optJSONObject(index) ?: continue
                    runCatching { AlarmRingSession.fromJson(rawSession) }
                        .getOrNull()
                        ?.let(::add)
                }
            }
        }
    }
}

