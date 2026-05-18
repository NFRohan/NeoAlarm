package dev.neoalarm.app.alarmengine

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.UserManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import java.time.ZoneId

internal class AlarmPermissionCommandHandler(
    context: Context,
    private val activity: Activity?,
    private val scheduler: AlarmScheduler,
    private val ringSessionStore: RingSessionStore,
) {
    private val appContext = context.applicationContext
    private val permissionPreferences = appContext.getSharedPreferences(
        PERMISSION_PREFS_NAME,
        Context.MODE_PRIVATE,
    )
    private val packageManager = appContext.packageManager
    private val sensorManager = appContext.getSystemService(SensorManager::class.java)
    private val locationManager = appContext.getSystemService(LocationManager::class.java)
    private val powerManager = appContext.getSystemService(PowerManager::class.java)
    private val userManager = appContext.getSystemService(UserManager::class.java)

    fun statusMap(): Map<String, Any?> {
        return mapOf(
            "canScheduleExactAlarms" to scheduler.canScheduleExactAlarms(),
            "notificationsEnabled" to NotificationManagerCompat.from(appContext)
                .areNotificationsEnabled(),
            "batteryOptimizationIgnored" to isIgnoringBatteryOptimizations(),
            "hasCamera" to packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY),
            "cameraPermissionGranted" to isPermissionGranted(Manifest.permission.CAMERA),
            "hasStepSensor" to hasStepSensor(),
            "activityRecognitionGranted" to isActivityRecognitionGranted(),
            "locationServicesEnabled" to isLocationServicesEnabled(),
            "foregroundLocationGranted" to isForegroundLocationGranted(),
            "backgroundLocationGranted" to isBackgroundLocationGranted(),
            "timezoneId" to ZoneId.systemDefault().id,
        )
    }

    fun startupContextMap(): Map<String, Any?> {
        return mapOf("userUnlocked" to isUserUnlocked())
    }

    fun requestExactAlarmPermission() {
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
    }

    fun requestNotificationPermission() {
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
    }

    fun requestBatteryOptimizationExemption() {
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
    }

    fun requestCameraPermission() {
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
            return
        }

        if (!isPermissionGranted(Manifest.permission.CAMERA)) {
            requestRuntimePermissionOrOpenSettings(
                Manifest.permission.CAMERA,
                REQUEST_CAMERA_CODE,
                KEY_CAMERA_REQUESTED,
            )
        }
    }

    fun requestActivityRecognitionPermission() {
        if (!hasStepSensor()) {
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
    }

    fun requestForegroundLocationPermission() {
        if (!isForegroundLocationGranted()) {
            requestRuntimePermissionOrOpenSettings(
                Manifest.permission.ACCESS_FINE_LOCATION,
                REQUEST_FOREGROUND_LOCATION_CODE,
                KEY_FOREGROUND_LOCATION_REQUESTED,
            )
        }
    }

    fun requestBackgroundLocationPermission() {
        if (!isForegroundLocationGranted()) {
            requestRuntimePermissionOrOpenSettings(
                Manifest.permission.ACCESS_FINE_LOCATION,
                REQUEST_FOREGROUND_LOCATION_CODE,
                KEY_FOREGROUND_LOCATION_REQUESTED,
            )
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            !isBackgroundLocationGranted()
        ) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                openAppDetailsSettings()
            } else {
                requestRuntimePermissionOrOpenSettings(
                    Manifest.permission.ACCESS_BACKGROUND_LOCATION,
                    REQUEST_BACKGROUND_LOCATION_CODE,
                    KEY_BACKGROUND_LOCATION_REQUESTED,
                )
            }
        }
    }

    fun openLocationSettings() {
        appContext.startActivity(
            Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
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

    private fun isForegroundLocationGranted(): Boolean {
        return isPermissionGranted(Manifest.permission.ACCESS_FINE_LOCATION)
    }

    private fun isBackgroundLocationGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            isPermissionGranted(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        } else {
            isForegroundLocationGranted()
        }
    }

    private fun isLocationServicesEnabled(): Boolean {
        return locationManager?.isLocationEnabled ?: false
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
        private const val KEY_BACKGROUND_LOCATION_REQUESTED = "background_location_requested"
        private const val KEY_CAMERA_REQUESTED = "camera_requested"
        private const val KEY_FOREGROUND_LOCATION_REQUESTED = "foreground_location_requested"
        private const val PERMISSION_PREFS_NAME = "alarm_engine_permission_prompts"
        private const val REQUEST_ACTIVITY_RECOGNITION_CODE = 1003
        private const val REQUEST_BACKGROUND_LOCATION_CODE = 1005
        private const val REQUEST_CAMERA_CODE = 1002
        private const val REQUEST_FOREGROUND_LOCATION_CODE = 1004
        private const val REQUEST_NOTIFICATIONS_CODE = 1001
    }
}
