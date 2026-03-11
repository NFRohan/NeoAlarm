package dev.alarmsoss.alarms_oss.alarmengine

import org.json.JSONObject

data class MissionSpec(
    val type: String,
    val mathDifficultyId: String? = null,
) {
    fun toChannelMap(): Map<String, Any?> {
        return mapOf(
            "type" to type,
            "config" to when (type) {
                TYPE_MATH -> mapOf("difficulty" to (mathDifficultyId ?: DEFAULT_MATH_DIFFICULTY))
                else -> emptyMap<String, Any?>()
            },
        )
    }

    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("type", type)
            put(
                "config",
                JSONObject().apply {
                    if (type == TYPE_MATH) {
                        put("difficulty", mathDifficultyId ?: DEFAULT_MATH_DIFFICULTY)
                    }
                },
            )
        }
    }

    companion object {
        const val TYPE_NONE = "none"
        const val TYPE_MATH = "math"
        const val TYPE_STEPS = "steps"
        const val TYPE_QR = "qr"
        const val DEFAULT_MATH_DIFFICULTY = "standard"

        fun fromChannelMap(raw: Map<*, *>?, fallbackType: String? = null): MissionSpec {
            val type = (raw?.get("type") as? String) ?: fallbackType ?: TYPE_NONE
            val config = raw?.get("config") as? Map<*, *>

            return MissionSpec(
                type = type,
                mathDifficultyId = when (type) {
                    TYPE_MATH -> (config?.get("difficulty") as? String) ?: DEFAULT_MATH_DIFFICULTY
                    else -> null
                },
            )
        }

        fun fromJson(json: JSONObject?, fallbackType: String? = null): MissionSpec {
            val type = json?.optString("type")?.takeIf(String::isNotBlank) ?: fallbackType ?: TYPE_NONE
            val config = json?.optJSONObject("config")

            return MissionSpec(
                type = type,
                mathDifficultyId = when (type) {
                    TYPE_MATH -> config?.optString("difficulty", DEFAULT_MATH_DIFFICULTY)
                        ?: DEFAULT_MATH_DIFFICULTY
                    else -> null
                },
            )
        }
    }
}
