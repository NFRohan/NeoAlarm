package dev.neoalarm.app.alarmengine

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import java.util.concurrent.TimeUnit

internal class LocationGeofenceRegistrar(context: Context) {
    private val logTag = "NeoAlarmLocation"
    private val appContext = context.applicationContext
    private val geofencingClient = LocationServices.getGeofencingClient(appContext)

    fun register(record: AlarmRecord) {
        val trigger = requireNotNull(record.locationTrigger) {
            "Location geofence registration requires a location trigger."
        }
        val request = GeofencingRequest.Builder()
            .setInitialTrigger(0)
            .addGeofence(buildInnerGeofence(record.id, trigger))
            .addGeofence(buildOuterGeofence(record.id, trigger))
            .build()

        addGeofencesAfterPermissionCheck(request)
    }

    fun unregister(record: AlarmRecord) {
        val geofenceIds = listOf(
            record.locationTrigger?.geofenceId
                ?: LocationAlarmConfig.geofenceIdFor(record.id),
            LocationAlarmConfig.outerGeofenceIdFor(record.id),
        )
        runCatching {
            awaitPlayServicesTask(geofencingClient.removeGeofences(geofenceIds))
        }.onFailure { error ->
            Log.w(
                logTag,
                "Failed to unregister geofences for location alarm ${record.id}: ${error.message}",
                error,
            )
        }
    }

    fun isCurrentRegistrationReusable(
        record: AlarmRecord,
        expectedGeofenceId: String,
    ): Boolean {
        val trigger = record.locationTrigger ?: return false
        if (trigger.geofenceId != expectedGeofenceId ||
            trigger.registeredAtEpochMillis == null
        ) {
            return false
        }

        return when (trigger.health) {
            LocationAlarmHealth.HEALTHY,
            LocationAlarmHealth.WAITING_FOR_EXIT,
            LocationAlarmHealth.BATTERY_RESTRICTED,
            LocationAlarmHealth.LOW_LOCATION_CONFIDENCE,
            -> true

            LocationAlarmHealth.UNKNOWN,
            LocationAlarmHealth.REARM_PENDING,
            LocationAlarmHealth.NO_FOREGROUND_PERMISSION,
            LocationAlarmHealth.NO_BACKGROUND_PERMISSION,
            LocationAlarmHealth.LOCATION_DISABLED,
            LocationAlarmHealth.GEOFENCE_NOT_REGISTERED,
            LocationAlarmHealth.PLAY_SERVICES_UNAVAILABLE,
            -> false
        }
    }

    private fun buildInnerGeofence(
        alarmId: String,
        trigger: LocationAlarmRecord,
    ): Geofence {
        return Geofence.Builder()
            .setRequestId(LocationAlarmConfig.geofenceIdFor(alarmId))
            .setCircularRegion(
                trigger.latitude,
                trigger.longitude,
                trigger.radiusMeters.toFloat(),
            )
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .build()
    }

    private fun buildOuterGeofence(
        alarmId: String,
        trigger: LocationAlarmRecord,
    ): Geofence {
        return Geofence.Builder()
            .setRequestId(LocationAlarmConfig.outerGeofenceIdFor(alarmId))
            .setCircularRegion(
                trigger.latitude,
                trigger.longitude,
                LocationAlarmConfig.outerRadiusMetersFor(trigger).toFloat(),
            )
            .setTransitionTypes(
                Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT,
            )
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .build()
    }

    private fun geofencePendingIntent(): PendingIntent {
        val intent = Intent()
            .setClass(appContext, LocationAlarmReceiver::class.java)
            .setPackage(appContext.packageName)
        val flags = PendingIntent.FLAG_CANCEL_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }

        return PendingIntent.getBroadcast(
            appContext,
            LocationAlarmConfig.LOCATION_GEOFENCE_PENDING_INTENT_REQUEST_CODE,
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
    private fun addGeofencesAfterPermissionCheck(request: GeofencingRequest) {
        awaitPlayServicesTask(geofencingClient.addGeofences(request, geofencePendingIntent()))
    }
}
