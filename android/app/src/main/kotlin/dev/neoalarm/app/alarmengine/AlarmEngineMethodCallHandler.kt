package dev.neoalarm.app.alarmengine

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.UserManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.ZoneId

class AlarmEngineMethodCallHandler(
    context: Context,
    private val activity: Activity?,
) : MethodChannel.MethodCallHandler {
    private val permissionPreferences = context.applicationContext.getSharedPreferences(
        PERMISSION_PREFS_NAME,
        Context.MODE_PRIVATE,
    )
    private val appContext = context.applicationContext
    private val store = AlarmStore(appContext)
    private val ringSessionStore = RingSessionStore(appContext)
    private val scheduler = AlarmScheduler(appContext, store)
    private val packageManager = appContext.packageManager
    private val sensorManager = appContext.getSystemService(SensorManager::class.java)
    private val powerManager = appContext.getSystemService(PowerManager::class.java)
    private val userManager = appContext.getSystemService(UserManager::class.java)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getStatus" -> result.success(
                    mapOf(
                        "canScheduleExactAlarms" to scheduler.canScheduleExactAlarms(),
                        "notificationsEnabled" to NotificationManagerCompat.from(appContext)
                            .areNotificationsEnabled(),
                        "batteryOptimizationIgnored" to isIgnoringBatteryOptimizations(),
                        "hasCamera" to packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY),
                        "cameraPermissionGranted" to isPermissionGranted(Manifest.permission.CAMERA),
                        "hasStepSensor" to hasStepSensor(),
                        "activityRecognitionGranted" to isActivityRecognitionGranted(),
                        "timezoneId" to ZoneId.systemDefault().id,
                    ),
                )

                "getStartupContext" -> result.success(
                    mapOf(
                        "userUnlocked" to isUserUnlocked(),
                    ),
                )

                "listAlarms" -> result.success(
                    store.getAll()
                        .sortedWith(
                            compareBy<AlarmRecord> { it.nextTriggerAtEpochMillis ?: Long.MAX_VALUE }
                                .thenBy { it.hour }
                                .thenBy { it.minute },
                        )
                        .map(AlarmRecord::toChannelMap),
                )

                "getActiveSession" -> {
                    val session = activeSession()
                    if (session?.isMissionActive == true &&
                        session.mission.spec.type == MissionSpec.TYPE_STEPS
                    ) {
                        StepMissionTracker.ensureRunning(appContext, session)
                    }
                    result.success(activeSession()?.toChannelMap())
                }

                "upsertAlarm" -> {
                    val raw = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Alarm payload missing.")
                    val record = AlarmRecord.fromChannelMap(raw)
                    result.success(scheduler.upsert(record).toChannelMap())
                }

                "setAlarmEnabled" -> {
                    val raw = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Alarm toggle payload missing.")
                    val id = raw["id"] as? String
                        ?: throw IllegalArgumentException("Alarm id missing.")
                    val enabled = raw["enabled"] as? Boolean
                        ?: throw IllegalArgumentException("Enabled flag missing.")
                    result.success(scheduler.updateEnabled(id, enabled).toChannelMap())
                }

                "deleteAlarm" -> {
                    val raw = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Delete payload missing.")
                    val id = raw["id"] as? String
                        ?: throw IllegalArgumentException("Alarm id missing.")
                    scheduler.delete(id)
                    result.success(null)
                }

                "rescheduleAll" -> {
                    scheduler.rescheduleAll()
                    result.success(null)
                }

                "dismissActiveSession" -> {
                    val session = activeSession()
                    if (session != null && !session.mission.isDismissAllowed) {
                        throw IllegalStateException("Complete the active mission before dismissing this alarm.")
                    }
                    AlarmRingingService.dismiss(appContext)
                    result.success(null)
                }

                "snoozeActiveSession" -> {
                    val session = activeSession()
                        ?: throw IllegalStateException("No active session to snooze.")
                    if (!session.canSnooze) {
                        throw IllegalStateException("Snooze limit reached for this alarm.")
                    }
                    AlarmRingingService.snooze(appContext)
                    result.success(null)
                }

                "startMission" -> {
                    val session = activeSession()
                        ?: throw IllegalStateException("No active mission session.")
                    if (session.mission.spec.type == MissionSpec.TYPE_NONE) {
                        throw IllegalStateException("This alarm does not require a mission.")
                    }
                    AlarmRingingService.beginMission(appContext)
                    result.success(null)
                }

                "registerMissionActivity" -> {
                    val session = activeSession()
                        ?: throw IllegalStateException("No active mission session.")
                    if (session.isMissionActive) {
                        if (session.mission.spec.type == MissionSpec.TYPE_STEPS) {
                            StepMissionTracker.ensureRunning(appContext, session)
                        }
                        AlarmSessionCoordinator.extendMissionTimeout(appContext, session)
                    }
                    result.success(null)
                }

                "submitMathAnswer" -> {
                    val raw = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Math answer payload missing.")
                    val session = activeSession()
                        ?: throw IllegalStateException("No active ringing session.")
                    val answer = raw["answer"] as? String
                        ?: throw IllegalArgumentException("Math answer missing.")
                    val (updatedMission, submissionResult) = session.mission.submitMathAnswer(answer)

                    when (submissionResult) {
                        MathAnswerSubmissionResult.COMPLETED -> {
                            AlarmRingingService.dismiss(appContext)
                        }

                        MathAnswerSubmissionResult.ADVANCED,
                        MathAnswerSubmissionResult.INCORRECT,
                        -> {
                            AlarmSessionCoordinator.extendMissionTimeout(
                                appContext,
                                session.withMission(updatedMission),
                            )
                        }
                    }

                    result.success(submissionResult.id)
                }

                "requestExactAlarmPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                        !scheduler.canScheduleExactAlarms()
                    ) {
                        appContext.startActivity(
                            Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                data = Uri.parse("package:${appContext.packageName}")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            },
                        )
                    }
                    result.success(null)
                }

                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = isPermissionGranted(Manifest.permission.POST_NOTIFICATIONS)

                        if (!granted) {
                            requestRuntimePermission(
                                Manifest.permission.POST_NOTIFICATIONS,
                                REQUEST_NOTIFICATIONS_CODE,
                            )
                        }
                    } else {
                        appContext.startActivity(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, appContext.packageName)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            },
                        )
                    }
                    result.success(null)
                }

                "requestBatteryOptimizationExemption" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                        !isIgnoringBatteryOptimizations()
                    ) {
                        appContext.startActivity(
                            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:${appContext.packageName}")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            },
                        )
                    }
                    result.success(null)
                }

                "requestCameraPermission" -> {
                    if (!packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
                        result.success(null)
                        return
                    }

                    if (!isPermissionGranted(Manifest.permission.CAMERA)) {
                        requestRuntimePermissionOrOpenSettings(
                            Manifest.permission.CAMERA,
                            REQUEST_CAMERA_CODE,
                            KEY_CAMERA_REQUESTED,
                        )
                    }
                    result.success(null)
                }

                "requestActivityRecognitionPermission" -> {
                    if (!hasStepSensor()) {
                        result.success(null)
                        return
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                        !isPermissionGranted(Manifest.permission.ACTIVITY_RECOGNITION)
                    ) {
                        requestRuntimePermissionOrOpenSettings(
                            Manifest.permission.ACTIVITY_RECOGNITION,
                            REQUEST_ACTIVITY_RECOGNITION_CODE,
                            KEY_ACTIVITY_RECOGNITION_REQUESTED,
                        )
                    }
                    if (activeSession()?.mission?.spec?.type == MissionSpec.TYPE_STEPS) {
                        StepMissionTracker.ensureRunning(appContext, activeSession())
                    }
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (error: ExactAlarmPermissionException) {
            result.error("exact_alarm_denied", error.message, null)
        } catch (error: Exception) {
            result.error("alarm_engine_error", error.message, null)
        }
    }

    private fun hasStepSensor(): Boolean {
        return sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR) != null
    }

    private fun activeSession(): AlarmRingSession? {
        return ringSessionStore.get()?.takeIf(AlarmRingSession::isActive)
    }

    private fun isActivityRecognitionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            isPermissionGranted(Manifest.permission.ACTIVITY_RECOGNITION)
        } else {
            true
        }
    }

    private fun isPermissionGranted(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(
            appContext,
            permission,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            powerManager.isIgnoringBatteryOptimizations(appContext.packageName)
        } else {
            true
        }
    }

    private fun isUserUnlocked(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            userManager?.isUserUnlocked ?: true
        } else {
            true
        }
    }

    private fun requestRuntimePermission(permission: String, requestCode: Int) {
        val hostActivity = activity
            ?: throw IllegalStateException("Activity unavailable for permission request.")

        ActivityCompat.requestPermissions(
            hostActivity,
            arrayOf(permission),
            requestCode,
        )
    }

    private fun requestRuntimePermissionOrOpenSettings(
        permission: String,
        requestCode: Int,
        preferenceKey: String,
    ) {
        val hostActivity = activity
        if (hostActivity == null) {
            openAppDetailsSettings()
            return
        }

        val wasRequestedBefore = permissionPreferences.getBoolean(preferenceKey, false)
        val shouldRequestInApp = !wasRequestedBefore ||
            ActivityCompat.shouldShowRequestPermissionRationale(hostActivity, permission)

        if (shouldRequestInApp) {
            permissionPreferences.edit().putBoolean(preferenceKey, true).apply()
            requestRuntimePermission(permission, requestCode)
            return
        }

        openAppDetailsSettings()
    }

    private fun openAppDetailsSettings() {
        appContext.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${appContext.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
    }

    companion object {
        private const val KEY_ACTIVITY_RECOGNITION_REQUESTED = "activity_recognition_requested"
        private const val KEY_CAMERA_REQUESTED = "camera_requested"
        private const val PERMISSION_PREFS_NAME = "alarm_engine_permission_prompts"
        private const val REQUEST_ACTIVITY_RECOGNITION_CODE = 1003
        private const val REQUEST_CAMERA_CODE = 1002
        private const val REQUEST_NOTIFICATIONS_CODE = 1001
    }
}

