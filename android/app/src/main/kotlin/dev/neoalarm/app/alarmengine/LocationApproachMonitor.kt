package dev.neoalarm.app.alarmengine

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import java.util.concurrent.TimeUnit

internal class LocationApproachMonitor(
    context: Context,
    private val store: AlarmStore,
    private val readinessProbe: LocationReadinessProbe,
) {
    private val logTag = "NeoAlarmLocation"
    private val appContext = context.applicationContext
    private val fusedLocationClient = LocationServices.getFusedLocationProviderClient(appContext)

    fun sync() {
        val hasApproachingAlarms = store.getAll().any { record ->
            record.triggerKind == AlarmTriggerKind.LOCATION &&
                record.enabled &&
                record.locationTrigger?.approachState == LocationAlarmApproachState.APPROACHING
        }

        val pendingIntent = passiveLocationPendingIntent()
        if (!hasApproachingAlarms) {
            removePassiveLocationUpdates(pendingIntent, "Unable to remove passive approach listener")
            return
        }

        val blockingHealth = readinessProbe.blockingHealth(requireBackgroundPermission = true)
        if (blockingHealth != null) {
            removePassiveLocationUpdates(
                pendingIntent,
                "Unable to remove stale passive approach listener",
            )
            markApproachingAlarmsUnhealthy(blockingHealth)
            return
        }

        val request = LocationRequest.Builder(
            Priority.PRIORITY_PASSIVE,
            LocationAlarmConfig.PASSIVE_LOCATION_UPDATE_INTERVAL_MS,
        )
            .setMinUpdateIntervalMillis(LocationAlarmConfig.PASSIVE_LOCATION_UPDATE_INTERVAL_MS)
            .build()

        runCatching {
            requestPassiveLocationUpdatesAfterPermissionCheck(request, pendingIntent)
        }.onFailure { error ->
            Log.w(logTag, "Unable to register passive approach listener: ${error.message}", error)
            markApproachingAlarmsUnhealthy(LocationAlarmHealth.GEOFENCE_NOT_REGISTERED)
        }
    }

    private fun removePassiveLocationUpdates(
        pendingIntent: PendingIntent,
        message: String,
    ) {
        runCatching {
            awaitPlayServicesTask(fusedLocationClient.removeLocationUpdates(pendingIntent))
        }.onFailure { error ->
            Log.w(logTag, "$message: ${error.message}", error)
        }
    }

    private fun markApproachingAlarmsUnhealthy(health: LocationAlarmHealth) {
        store.getAll().forEach { record ->
            val trigger = record.locationTrigger ?: return@forEach
            if (record.triggerKind != AlarmTriggerKind.LOCATION ||
                !record.enabled ||
                trigger.approachState != LocationAlarmApproachState.APPROACHING
            ) {
                return@forEach
            }

            store.upsert(
                record.copy(
                    locationTrigger = trigger.copy(
                        health = health,
                        approachState = LocationAlarmApproachState.IDLE,
                        approachEnteredAtEpochMillis = null,
                    ),
                ),
            )
        }
    }

    private fun passiveLocationPendingIntent(): PendingIntent {
        val intent = Intent(LocationAlarmReceiver.ACTION_PASSIVE_LOCATION_UPDATE)
            .setClass(appContext, LocationAlarmReceiver::class.java)
            .setPackage(appContext.packageName)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }

        return PendingIntent.getBroadcast(
            appContext,
            LocationAlarmConfig.LOCATION_PASSIVE_UPDATES_PENDING_INTENT_REQUEST_CODE,
            intent,
            flags,
        )
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
    private fun requestPassiveLocationUpdatesAfterPermissionCheck(
        request: LocationRequest,
        pendingIntent: PendingIntent,
    ) {
        awaitPlayServicesTask(fusedLocationClient.requestLocationUpdates(request, pendingIntent))
    }
}
