package dev.neoalarm.app.alarmengine

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.LocationResult

class LocationAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        Thread {
            try {
                handleReceive(context.applicationContext, intent)
            } catch (error: Exception) {
                Log.e(logTag, "Location alarm broadcast failed: ${error.message}", error)
            } finally {
                pendingResult.finish()
            }
        }.start()
    }

    private fun handleReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_PASSIVE_LOCATION_UPDATE) {
            val location = LocationResult.extractResult(intent)?.lastLocation ?: return
            LocationAlarmCoordinator(context, AlarmStore(context))
                .handlePassiveLocationUpdate(location, System.currentTimeMillis())
            return
        }

        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) {
            Log.w(logTag, "Geofence broadcast error apiCode=${event.errorCode}.")
            LocationAlarmCoordinator(context, AlarmStore(context))
                .handleGeofenceDeliveryError(event.errorCode)
            return
        }

        val coordinator = LocationAlarmCoordinator(context, AlarmStore(context))
        val now = System.currentTimeMillis()

        event.triggeringGeofences.orEmpty()
            .forEach { geofence ->
                val requestId = geofence.requestId
                when {
                    requestId.startsWith(LocationAlarmConfig.INNER_GEOFENCE_ID_PREFIX) &&
                        event.geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER -> {
                        coordinator.triggerLocationAlarm(
                            requestId.removePrefix(LocationAlarmConfig.INNER_GEOFENCE_ID_PREFIX),
                            now,
                        )
                    }

                    requestId.startsWith(LocationAlarmConfig.OUTER_GEOFENCE_ID_PREFIX) &&
                        event.geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER -> {
                        coordinator.handleApproachZoneEntered(
                            requestId.removePrefix(LocationAlarmConfig.OUTER_GEOFENCE_ID_PREFIX),
                            now,
                        )
                    }

                    requestId.startsWith(LocationAlarmConfig.OUTER_GEOFENCE_ID_PREFIX) &&
                        event.geofenceTransition == Geofence.GEOFENCE_TRANSITION_EXIT -> {
                        coordinator.handleApproachZoneExited(
                            requestId.removePrefix(LocationAlarmConfig.OUTER_GEOFENCE_ID_PREFIX),
                        )
                    }
                }
            }
    }

    companion object {
        private const val logTag = "NeoAlarmLocationRx"
        const val ACTION_PASSIVE_LOCATION_UPDATE =
            "dev.neoalarm.app.action.PASSIVE_LOCATION_UPDATE"
    }
}
