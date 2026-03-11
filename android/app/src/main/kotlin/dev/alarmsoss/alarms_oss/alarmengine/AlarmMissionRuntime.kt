package dev.alarmsoss.alarms_oss.alarmengine

import kotlin.random.Random
import org.json.JSONObject

data class MathChallengeState(
    val leftOperand: Int,
    val rightOperand: Int,
    val operatorSymbol: String,
    val correctAnswer: Int,
    val attemptCount: Int,
) {
    fun toChannelMap(): Map<String, Any> {
        return mapOf(
            "leftOperand" to leftOperand,
            "rightOperand" to rightOperand,
            "operatorSymbol" to operatorSymbol,
            "attemptCount" to attemptCount,
        )
    }

    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("leftOperand", leftOperand)
            put("rightOperand", rightOperand)
            put("operatorSymbol", operatorSymbol)
            put("correctAnswer", correctAnswer)
            put("attemptCount", attemptCount)
        }
    }

    fun withAttemptIncremented(): MathChallengeState {
        return copy(attemptCount = attemptCount + 1)
    }

    companion object {
        fun fromJson(json: JSONObject): MathChallengeState {
            return MathChallengeState(
                leftOperand = json.getInt("leftOperand"),
                rightOperand = json.getInt("rightOperand"),
                operatorSymbol = json.getString("operatorSymbol"),
                correctAnswer = json.getInt("correctAnswer"),
                attemptCount = json.optInt("attemptCount", 0),
            )
        }

        fun generate(difficultyId: String): MathChallengeState {
            return when (difficultyId) {
                "easy" -> generateEasyChallenge()
                "hard" -> generateHardChallenge()
                else -> generateStandardChallenge()
            }
        }

        private fun generateEasyChallenge(): MathChallengeState {
            val addition = Random.nextBoolean()
            val left = Random.nextInt(2, 10)
            val right = Random.nextInt(1, 10)

            return if (addition) {
                MathChallengeState(
                    leftOperand = left,
                    rightOperand = right,
                    operatorSymbol = "+",
                    correctAnswer = left + right,
                    attemptCount = 0,
                )
            } else {
                val max = maxOf(left, right)
                val min = minOf(left, right)
                MathChallengeState(
                    leftOperand = max,
                    rightOperand = min,
                    operatorSymbol = "-",
                    correctAnswer = max - min,
                    attemptCount = 0,
                )
            }
        }

        private fun generateStandardChallenge(): MathChallengeState {
            return when (Random.nextInt(3)) {
                0 -> {
                    val left = Random.nextInt(10, 40)
                    val right = Random.nextInt(5, 25)
                    MathChallengeState(
                        leftOperand = left,
                        rightOperand = right,
                        operatorSymbol = "+",
                        correctAnswer = left + right,
                        attemptCount = 0,
                    )
                }

                1 -> {
                    val left = Random.nextInt(25, 60)
                    val right = Random.nextInt(5, 25)
                    MathChallengeState(
                        leftOperand = left,
                        rightOperand = right,
                        operatorSymbol = "-",
                        correctAnswer = left - right,
                        attemptCount = 0,
                    )
                }

                else -> {
                    val left = Random.nextInt(3, 10)
                    val right = Random.nextInt(3, 10)
                    MathChallengeState(
                        leftOperand = left,
                        rightOperand = right,
                        operatorSymbol = "×",
                        correctAnswer = left * right,
                        attemptCount = 0,
                    )
                }
            }
        }

        private fun generateHardChallenge(): MathChallengeState {
            return when (Random.nextInt(2)) {
                0 -> {
                    val left = Random.nextInt(8, 15)
                    val right = Random.nextInt(7, 13)
                    MathChallengeState(
                        leftOperand = left,
                        rightOperand = right,
                        operatorSymbol = "×",
                        correctAnswer = left * right,
                        attemptCount = 0,
                    )
                }

                else -> {
                    val left = Random.nextInt(40, 95)
                    val right = Random.nextInt(15, 50)
                    MathChallengeState(
                        leftOperand = left,
                        rightOperand = right,
                        operatorSymbol = "+",
                        correctAnswer = left + right,
                        attemptCount = 0,
                    )
                }
            }
        }
    }
}

data class AlarmMissionRuntime(
    val spec: MissionSpec,
    val status: String,
    val mathChallenge: MathChallengeState?,
) {
    fun toChannelMap(): Map<String, Any?> {
        return buildMap {
            putAll(spec.toChannelMap())
            put("status", status)
            put("mathChallenge", mathChallenge?.toChannelMap())
        }
    }

    fun toJson(): JSONObject {
        return spec.toJson().apply {
            put("status", status)
            put("mathChallenge", mathChallenge?.toJson())
        }
    }

    val isDismissAllowed: Boolean
        get() = spec.type == MissionSpec.TYPE_NONE || status == STATUS_COMPLETED

    fun submitMathAnswer(answerRaw: String): Pair<AlarmMissionRuntime, Boolean> {
        if (spec.type != MissionSpec.TYPE_MATH) {
            return copy(status = STATUS_COMPLETED) to true
        }

        val challenge = mathChallenge ?: return this to false
        val answer = answerRaw.trim().toIntOrNull()
        if (answer != null && answer == challenge.correctAnswer) {
            return copy(status = STATUS_COMPLETED) to true
        }

        return copy(mathChallenge = challenge.withAttemptIncremented()) to false
    }

    companion object {
        const val STATUS_PENDING = "pending"
        const val STATUS_COMPLETED = "completed"

        fun create(spec: MissionSpec): AlarmMissionRuntime {
            return when (spec.type) {
                MissionSpec.TYPE_NONE -> AlarmMissionRuntime(
                    spec = spec,
                    status = STATUS_COMPLETED,
                    mathChallenge = null,
                )

                MissionSpec.TYPE_MATH -> AlarmMissionRuntime(
                    spec = spec,
                    status = STATUS_PENDING,
                    mathChallenge = MathChallengeState.generate(
                        spec.mathDifficultyId ?: MissionSpec.DEFAULT_MATH_DIFFICULTY,
                    ),
                )

                else -> AlarmMissionRuntime(
                    spec = spec,
                    status = STATUS_PENDING,
                    mathChallenge = null,
                )
            }
        }

        fun fromJson(json: JSONObject): AlarmMissionRuntime {
            val challengeJson = json.optJSONObject("mathChallenge")
            return AlarmMissionRuntime(
                spec = MissionSpec.fromJson(json),
                status = json.optString("status", STATUS_PENDING),
                mathChallenge = challengeJson?.let(MathChallengeState::fromJson),
            )
        }
    }
}
