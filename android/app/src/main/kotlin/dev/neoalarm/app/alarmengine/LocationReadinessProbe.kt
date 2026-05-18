package dev.neoalarm.app.alarmengine

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

internal class LocationReadinessProbe(context: Context) {
    private val logTag = "NeoAlarmLocation"
    private val appContext = context.applicationContext
    private val fusedLocationClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(appContext)
    private val googleApiAvailability = GoogleApiAvailability.getInstance()
    private val locationManager = appContext.getSystemService(LocationManager::class.java)
    private val powerManager = appContext.getSystemService(PowerManager::class.java)

    fun blockingHealth(requireBackgroundPermission: Boolean = true): LocationAlarmHealth? {
        if (!isForegroundLocationGranted()) {
            return LocationAlarmHealth.NO_FOREGROUND_PERMISSION
        }
        if (requireBackgroundPermission && !isBackgroundLocationGranted()) {
            return LocationAlarmHealth.NO_BACKGROUND_PERMISSION
        }
        if (!isLocationEnabled()) {
            return LocationAlarmHealth.LOCATION_DISABLED
        }
        if (playServicesStatus() != ConnectionResult.SUCCESS) {
            return LocationAlarmHealth.PLAY_SERVICES_UNAVAILABLE
        }

        return null
    }

    fun warningHealth(): LocationAlarmHealth {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !powerManager.isIgnoringBatteryOptimizations(appContext.packageName)
        ) {
            LocationAlarmHealth.BATTERY_RESTRICTED
        } else {
            LocationAlarmHealth.HEALTHY
        }
    }

    fun currentLocationSnapshot(
        requireBackgroundPermission: Boolean = true,
        allowActiveRequest: Boolean = true,
    ): Location? {
        if (blockingHealth(requireBackgroundPermission) != null) {
            return null
        }

        val lastLocation = runCatching {
            getLastLocationAfterPermissionCheck()
        }.onFailure { error ->
            Log.w(logTag, "Unable to read last known location: ${error.message}", error)
        }.getOrNull()

        if (lastLocation != null || !allowActiveRequest) {
            return lastLocation
        }

        val tokenSource = CancellationTokenSource()
        return runCatching {
            getCurrentLocationAfterPermissionCheck(tokenSource)
        }.onFailure { error ->
            if (error is TimeoutException) {
                tokenSource.cancel()
            }
            Log.w(logTag, "Unable to request current location: ${error.message}", error)
        }.getOrNull()
    }

    fun isForegroundLocationGranted(): Boolean {
        return ContextCompat.checkSelfPermission(
            appContext,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun isBackgroundLocationGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(
                appContext,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            isForegroundLocationGranted()
        }
    }

    fun isLocationEnabled(): Boolean {
        return locationManager?.isLocationEnabled ?: false
    }

    fun playServicesStatus(): Int {
        return googleApiAvailability.isGooglePlayServicesAvailable(appContext)
    }

    private fun <T> awaitPlayServicesTask(
        task: Task<T>,
        timeoutMillis: Long = LocationAlarmConfig.PLAY_SERVICES_TASK_TIMEOUT_MS,
    ): T {
        return try {
            Tasks.await(task, timeoutMillis, TimeUnit.MILLISECONDS)
        } catch (error: InterruptedException) {
            Thread.currentThread().interrupt()
            throw error
        }
    }

    @SuppressLint("MissingPermission")
    private fun getLastLocationAfterPermissionCheck(): Location? {
        return awaitPlayServicesTask(fusedLocationClient.lastLocation)
    }

    @SuppressLint("MissingPermission")
    private fun getCurrentLocationAfterPermissionCheck(
        tokenSource: CancellationTokenSource,
    ): Location? {
        return awaitPlayServicesTask(
            fusedLocationClient.getCurrentLocation(
                Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                tokenSource.token,
            ),
            LocationAlarmConfig.CURRENT_LOCATION_TASK_TIMEOUT_MS,
        )
    }
}
