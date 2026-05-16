package dev.neoalarm.app.alarmengine

import android.content.Context
import org.json.JSONArray

class AlarmStore(context: Context) {
    private val prefs =
        alarmEngineStorageContext(context)
            .getSharedPreferences(ALARM_ENGINE_PREFS_NAME, Context.MODE_PRIVATE)

    fun getAll(): List<AlarmRecord> {
        val raw = prefs.getString(KEY_ALARMS, "[]") ?: "[]"
        val array = JSONArray(raw)

        return buildList {
            for (index in 0 until array.length()) {
                add(AlarmRecord.fromJson(array.getJSONObject(index)))
            }
        }
    }

    fun get(id: String): AlarmRecord? {
        return getAll().firstOrNull { it.id == id }
    }

    fun replaceAll(records: List<AlarmRecord>) {
        val json = JSONArray().apply {
            records.forEach { put(it.toJson()) }
        }

        prefs.edit().putString(KEY_ALARMS, json.toString()).apply()
    }

    fun upsert(record: AlarmRecord): AlarmRecord {
        val current = getAll()
        val existingIndex = current.indexOfFirst { it.id == record.id }
        val updated = current.toMutableList()

        if (existingIndex >= 0) {
            updated[existingIndex] = record
        } else {
            updated.add(record)
        }

        replaceAll(updated)
        return record
    }

    fun delete(id: String) {
        replaceAll(getAll().filterNot { it.id == id })
    }

    companion object {
        private const val KEY_ALARMS = "alarms"
    }
}

