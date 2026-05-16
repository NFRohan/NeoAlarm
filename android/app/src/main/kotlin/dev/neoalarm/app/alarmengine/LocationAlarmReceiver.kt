package dev.neoalarm.app.alarmengine

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.LocationResult

class LocationAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_PASSIVE_LOCATION_UPDATE) {
            val location = LocationResult.extractResult(intent)?.lastLocation ?: return
            LocationAlarmCoordinator(context, AlarmStore(context))
                .handlePassiveLocationUpdate(location, System.currentTimeMillis())
            return
        }

        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) {
            return
        }

        val coordinator = LocationAlarmCoordinator(context, AlarmStore(context))
        val now = System.currentTimeMillis()

        event.triggeringGeofences.orEmpty()
            .forEach { geofence ->
                val requestId = geofence.requestId
                when {
                    requestId.startsWith(LocationAlarmCoordinator.innerGeofenceIdPrefix) &&
                        event.geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER -> {
                        coordinator.triggerLocationAlarm(
                            requestId.removePrefix(LocationAlarmCoordinator.innerGeofenceIdPrefix),
                            now,
                        )
                    }

                    requestId.startsWith(LocationAlarmCoordinator.outerGeofenceIdPrefix) &&
                        event.geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER -> {
                        coordinator.handleApproachZoneEntered(
                            requestId.removePrefix(LocationAlarmCoordinator.outerGeofenceIdPrefix),
                            now,
                        )
                    }

                    requestId.startsWith(LocationAlarmCoordinator.outerGeofenceIdPrefix) &&
                        event.geofenceTransition == Geofence.GEOFENCE_TRANSITION_EXIT -> {
                        coordinator.handleApproachZoneExited(
                            requestId.removePrefix(LocationAlarmCoordinator.outerGeofenceIdPrefix),
                        )
                    }
                }
            }
    }

    companion object {
        const val ACTION_PASSIVE_LOCATION_UPDATE =
            "dev.neoalarm.app.action.PASSIVE_LOCATION_UPDATE"
    }
}
