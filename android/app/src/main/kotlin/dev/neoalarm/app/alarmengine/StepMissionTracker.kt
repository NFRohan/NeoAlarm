package dev.neoalarm.app.alarmengine

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import androidx.core.content.ContextCompat

object StepMissionTracker {
    // Accept only human-plausible step cadence to reject shake bursts.
    private const val MIN_STEP_INTERVAL_NANOS = 180_000_000L

    private var listener: SensorEventListener? = null
    private var sensorManager: SensorManager? = null
    private var trackedSessionId: String? = null
    private var lastAcceptedStepAtNanos = 0L

    fun ensureRunning(context: Context, session: AlarmRingSession? = null) {
        val appContext = context.applicationContext
        val store = RingSessionStore(appContext)
        val activeSession = session ?: store.get()

        if (activeSession == null ||
            !activeSession.isMissionActive ||
            activeSession.mission.spec.type != MissionSpec.TYPE_STEPS
        ) {
            stop()
            return
        }

        val resolvedSensorManager = appContext.getSystemService(SensorManager::class.java)
        val stepSensor = resolvedSensorManager?.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
        if (stepSensor == null) {
            store.put(
                activeSession.withMission(
                    activeSession.mission.withStepTrackingState(
                        StepMissionTrackingState.UNSUPPORTED_SENSOR,
                    ),
                ),
            )
            stop()
            return
        }

        if (!isActivityRecognitionGranted(appContext)) {
            store.put(
                activeSession.withMission(
                    activeSession.mission.withStepTrackingState(
                        StepMissionTrackingState.MISSING_PERMISSION,
                    ),
                ),
            )
            stop()
            return
        }

        if (trackedSessionId == activeSession.sessionId && listener != null) {
            return
        }

        val normalizedSession = activeSession.withMission(
            activeSession.mission.withStepTrackingState(
                StepMissionTrackingState.AWAITING_STEPS,
            ),
        )
        if (normalizedSession != activeSession) {
            store.put(normalizedSession)
        }

        stop()

        trackedSessionId = normalizedSession.sessionId
        sensorManager = resolvedSensorManager
        lastAcceptedStepAtNanos = 0L

        val eventListener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                val currentSession = store.get()?.takeIf {
                    it.sessionId == trackedSessionId &&
                        it.isMissionActive &&
                        it.mission.spec.type == MissionSpec.TYPE_STEPS
                } ?: run {
                    stop()
                    return
                }

                val eventTimestampNanos = event.timestamp
                if (lastAcceptedStepAtNanos != 0L &&
                    eventTimestampNanos - lastAcceptedStepAtNanos < MIN_STEP_INTERVAL_NANOS
                ) {
                    return
                }
                lastAcceptedStepAtNanos = eventTimestampNanos

                val detectedStepCount = event.values.firstOrNull()
                    ?.toInt()
                    ?.coerceAtLeast(1)
                    ?: 1
                val updatedMission = currentSession.mission.recordDetectedStep(detectedStepCount)
                val updatedSession = currentSession.withMission(updatedMission)
                AlarmSessionCoordinator.extendMissionTimeout(appContext, updatedSession)

                if (updatedMission.isDismissAllowed) {
                    stop()
                    AlarmRingingService.dismiss(appContext)
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
        }

        listener = eventListener
        resolvedSensorManager.registerListener(
            eventListener,
            stepSensor,
            SensorManager.SENSOR_DELAY_GAME,
        )
    }

    fun stop() {
        listener?.let { activeListener ->
            sensorManager?.unregisterListener(activeListener)
        }
        listener = null
        sensorManager = null
        trackedSessionId = null
        lastAcceptedStepAtNanos = 0L
    }

    private fun isActivityRecognitionGranted(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACTIVITY_RECOGNITION,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }
}

