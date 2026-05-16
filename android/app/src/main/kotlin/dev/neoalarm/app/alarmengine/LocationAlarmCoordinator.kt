package dev.neoalarm.app.alarmengine

import android.Manifest
import android.location.Location
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.tasks.Tasks

class LocationAlarmCoordinator(
    context: Context,
    private val store: AlarmStore,
) {
    private val logTag = "NeoAlarmLocation"
    private val appContext = context.applicationContext
    private val geofencingClient = LocationServices.getGeofencingClient(appContext)
    private val fusedLocationClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(appContext)
    private val googleApiAvailability = GoogleApiAvailability.getInstance()
    private val locationManager = appContext.getSystemService(LocationManager::class.java)
    private val powerManager = appContext.getSystemService(PowerManager::class.java)

    fun sync(record: AlarmRecord): AlarmRecord {
        if (record.triggerKind != AlarmTriggerKind.LOCATION || record.locationTrigger == null) {
            return record
        }

        if (!record.enabled) {
            Log.i(logTag, "Skipping geofence arm for disabled location alarm ${record.id}.")
            unregisterGeofence(record)
            val persisted = persist(
                record.copy(
                    locationTrigger = clearRegistration(record.locationTrigger),
                ),
            )
            syncPassiveApproachMonitoring()
            return persisted
        }

        val blockingHealth = deriveBlockingHealth()
        if (blockingHealth != null) {
            Log.w(
                logTag,
                "Cannot arm location alarm ${record.id}: " +
                    "health=${blockingHealth.id}, " +
                    "foregroundGranted=${isForegroundLocationGranted()}, " +
                    "backgroundGranted=${isBackgroundLocationGranted()}, " +
                    "locationEnabled=${locationManager?.isLocationEnabled ?: false}, " +
                    "playServices=${googleApiAvailability.isGooglePlayServicesAvailable(appContext)}",
            )
            unregisterGeofence(record)
            val persisted = persist(
                record.copy(
                    locationTrigger = clearRegistration(record.locationTrigger).copy(
                        health = blockingHealth,
                    ),
                ),
            )
            syncPassiveApproachMonitoring()
            return persisted
        }

        val geofenceId = geofenceIdFor(record.id)
        val innerGeofence = Geofence.Builder()
            .setRequestId(geofenceId)
            .setCircularRegion(
                record.locationTrigger.latitude,
                record.locationTrigger.longitude,
                record.locationTrigger.radiusMeters.toFloat(),
            )
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .build()
        val outerGeofence = Geofence.Builder()
            .setRequestId(outerGeofenceIdFor(record.id))
            .setCircularRegion(
                record.locationTrigger.latitude,
                record.locationTrigger.longitude,
                outerRadiusMetersFor(record.locationTrigger).toFloat(),
            )
            .setTransitionTypes(
                Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT,
            )
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .build()

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(0)
            .addGeofence(innerGeofence)
            .addGeofence(outerGeofence)
            .build()

        val currentLocation = currentLocationSnapshot()
        val distanceMeters = currentLocation?.distanceToLocationTrigger(record.locationTrigger)
        val healthAfterArm = if (
            distanceMeters != null &&
            distanceMeters <= record.locationTrigger.radiusMeters
        ) {
            LocationAlarmHealth.WAITING_FOR_EXIT
        } else {
            deriveWarningHealth()
        }
        val approachStateAfterArm = when {
            distanceMeters != null &&
                distanceMeters > record.locationTrigger.radiusMeters &&
                distanceMeters <= outerRadiusMetersFor(record.locationTrigger) -> {
                LocationAlarmApproachState.APPROACHING
            }

            distanceMeters == null &&
                record.locationTrigger.approachState == LocationAlarmApproachState.APPROACHING -> {
                LocationAlarmApproachState.APPROACHING
            }

            else -> {
                LocationAlarmApproachState.IDLE
            }
        }

        return try {
            Log.i(
                logTag,
                "Arming location alarm ${record.id} " +
                    "lat=${record.locationTrigger.latitude}, " +
                    "lng=${record.locationTrigger.longitude}, " +
                    "radius=${record.locationTrigger.radiusMeters}",
            )
            unregisterGeofence(record)
            Tasks.await(geofencingClient.addGeofences(request, geofencePendingIntent()))
            Log.i(logTag, "Location alarm ${record.id} armed with geofenceId=$geofenceId.")
            val persisted = persist(
                record.copy(
                    locationTrigger = record.locationTrigger.copy(
                        health = healthAfterArm,
                        geofenceId = geofenceId,
                        registeredAtEpochMillis = System.currentTimeMillis(),
                        approachState = approachStateAfterArm,
                        approachEnteredAtEpochMillis = if (
                            approachStateAfterArm == LocationAlarmApproachState.APPROACHING
                        ) {
                            record.locationTrigger.approachEnteredAtEpochMillis ?: System.currentTimeMillis()
                        } else {
                            null
                        },
                    ),
                ),
            )
            syncPassiveApproachMonitoring()
            persisted
        } catch (error: Exception) {
            val apiCode = (error as? ApiException)?.statusCode
            Log.e(
                logTag,
                "Failed to arm location alarm ${record.id} " +
                    "geofenceId=$geofenceId apiCode=${apiCode ?: "n/a"} " +
                    "message=${error.message}",
                error,
            )
            val persisted = persist(
                record.copy(
                    locationTrigger = clearRegistration(record.locationTrigger).copy(
                        health = LocationAlarmHealth.GEOFENCE_NOT_REGISTERED,
                    ),
                ),
            )
            syncPassiveApproachMonitoring()
            persisted
        }
    }

    fun syncAll() {
        store.getAll().forEach { record ->
            if (record.triggerKind == AlarmTriggerKind.LOCATION) {
                sync(record)
            }
        }
    }

    fun delete(id: String) {
        val current = store.get(id) ?: return
        if (current.triggerKind == AlarmTriggerKind.LOCATION) {
            unregisterGeofence(current)
        }
        AlarmScheduler(appContext, store).delete(id)
        syncPassiveApproachMonitoring()
    }

    fun evaluateDraft(trigger: LocationAlarmRecord): Map<String, Any?> {
        val blockingHealth = deriveBlockingHealth()
        if (blockingHealth != null) {
            return mapOf(
                "health" to blockingHealth.id,
                "alreadyInsideRadius" to false,
                "distanceMeters" to null,
            )
        }

        val currentLocation = currentLocationSnapshot(allowActiveRequest = false)
        val distanceMeters = currentLocation?.distanceToLocationTrigger(trigger)?.toInt()
        val alreadyInsideRadius = distanceMeters != null && distanceMeters <= trigger.radiusMeters

        return mapOf(
            "health" to deriveWarningHealth().id,
            "alreadyInsideRadius" to alreadyInsideRadius,
            "distanceMeters" to distanceMeters,
        )
    }

    fun currentLocationSnapshotMap(): Map<String, Any?>? {
        val location = currentLocationSnapshot(requireBackgroundPermission = false) ?: return null
        return mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracyMeters" to location.accuracy.toDouble(),
        )
    }

    fun runForegroundFallbackCheck(): List<String> {
        val currentLocation = currentLocationSnapshot(allowActiveRequest = false) ?: return emptyList()
        val now = System.currentTimeMillis()

        return buildList {
            store.getAll().forEach { record ->
                if (record.triggerKind != AlarmTriggerKind.LOCATION ||
                    !record.enabled ||
                    record.locationTrigger == null
                ) {
                    return@forEach
                }

                if (deriveBlockingHealth() != null) {
                    return@forEach
                }

                val distanceMeters = currentLocation
                    .distanceToLocationTrigger(record.locationTrigger)
                    .toInt()
                val outerRadiusMeters = outerRadiusMetersFor(record.locationTrigger)
                if (distanceMeters > record.locationTrigger.radiusMeters) {
                    if (record.locationTrigger.health == LocationAlarmHealth.WAITING_FOR_EXIT) {
                        val updated = record.copy(
                            locationTrigger = record.locationTrigger.copy(
                                health = deriveWarningHealth(),
                            ),
                        )
                        store.upsert(updated)
                    }
                    if (distanceMeters <= outerRadiusMeters &&
                        record.locationTrigger.approachState != LocationAlarmApproachState.APPROACHING
                    ) {
                        handleApproachZoneEntered(record.id, now)
                    } else if (
                        distanceMeters > outerRadiusMeters &&
                        record.locationTrigger.approachState == LocationAlarmApproachState.APPROACHING
                    ) {
                        handleApproachZoneExited(record.id)
                    }
                    return@forEach
                }

                if (record.locationTrigger.health == LocationAlarmHealth.WAITING_FOR_EXIT) {
                    return@forEach
                }

                if (triggerLocationAlarm(record.id, now)) {
                    Log.i(logTag, "Foreground fallback triggered location alarm ${record.id}.")
                    add(record.id)
                }
            }
        }
    }

    fun triggerLocationAlarm(
        alarmId: String,
        triggeredAtMillis: Long = System.currentTimeMillis(),
    ): Boolean {
        val current = store.get(alarmId) ?: return false
        if (current.triggerKind != AlarmTriggerKind.LOCATION ||
            !current.enabled ||
            current.locationTrigger == null
        ) {
            return false
        }

        val lastTransitionAt = current.locationTrigger.lastTransitionAtEpochMillis
        if (lastTransitionAt != null &&
            triggeredAtMillis - lastTransitionAt < DUPLICATE_TRIGGER_COOLDOWN_MS
        ) {
            return false
        }

        val updated = current.copy(
            locationTrigger = current.locationTrigger.copy(
                health = LocationAlarmHealth.HEALTHY,
                lastTransitionAtEpochMillis = triggeredAtMillis,
                approachState = LocationAlarmApproachState.IDLE,
                approachEnteredAtEpochMillis = null,
            ),
        )
        store.upsert(updated)
        syncPassiveApproachMonitoring()

        val triggered = AlarmScheduler(appContext, store).handleAlarmTriggered(alarmId) ?: return false
        Log.i(logTag, "Location transition triggered alarm $alarmId.")
        AlarmRingingService.start(appContext, triggered.id)
        return true
    }

    fun handleApproachZoneEntered(
        alarmId: String,
        enteredAtMillis: Long = System.currentTimeMillis(),
    ) {
        val current = store.get(alarmId) ?: return
        val trigger = current.locationTrigger ?: return
        if (current.triggerKind != AlarmTriggerKind.LOCATION || !current.enabled) {
            return
        }
        if (trigger.health == LocationAlarmHealth.WAITING_FOR_EXIT) {
            return
        }
        if (trigger.approachState == LocationAlarmApproachState.APPROACHING) {
            syncPassiveApproachMonitoring()
            return
        }

        store.upsert(
            current.copy(
                locationTrigger = trigger.copy(
                    approachState = LocationAlarmApproachState.APPROACHING,
                    approachEnteredAtEpochMillis = enteredAtMillis,
                ),
            ),
        )
        syncPassiveApproachMonitoring()
    }

    fun handleApproachZoneExited(alarmId: String) {
        val current = store.get(alarmId) ?: return
        val trigger = current.locationTrigger ?: return
        if (trigger.approachState != LocationAlarmApproachState.APPROACHING) {
            syncPassiveApproachMonitoring()
            return
        }

        store.upsert(
            current.copy(
                locationTrigger = trigger.copy(
                    approachState = LocationAlarmApproachState.IDLE,
                    approachEnteredAtEpochMillis = null,
                ),
            ),
        )
        syncPassiveApproachMonitoring()
    }

    fun handlePassiveLocationUpdate(
        location: Location,
        now: Long = System.currentTimeMillis(),
    ) {
        if (deriveBlockingHealth() != null) {
            syncPassiveApproachMonitoring()
            return
        }

        var approachStateChanged = false
        store.getAll().forEach { record ->
            if (record.triggerKind != AlarmTriggerKind.LOCATION ||
                !record.enabled ||
                record.locationTrigger == null
            ) {
                return@forEach
            }

            val trigger = record.locationTrigger
            if (trigger.approachState != LocationAlarmApproachState.APPROACHING) {
                return@forEach
            }

            val distanceMeters = location.distanceToLocationTrigger(trigger).toInt()
            if (distanceMeters <= trigger.radiusMeters) {
                if (trigger.health != LocationAlarmHealth.WAITING_FOR_EXIT) {
                    triggerLocationAlarm(record.id, now)
                }
                approachStateChanged = true
                return@forEach
            }

            if (distanceMeters > outerRadiusMetersFor(trigger)) {
                handleApproachZoneExited(record.id)
                approachStateChanged = true
            }
        }

        if (!approachStateChanged) {
            syncPassiveApproachMonitoring()
        }
    }

    private fun persist(record: AlarmRecord): AlarmRecord {
        store.upsert(record)
        return record
    }

    private fun clearRegistration(trigger: LocationAlarmRecord): LocationAlarmRecord {
        return trigger.copy(
            geofenceId = null,
            registeredAtEpochMillis = null,
            approachState = LocationAlarmApproachState.IDLE,
            approachEnteredAtEpochMillis = null,
        )
    }

    private fun unregisterGeofence(record: AlarmRecord) {
        val geofenceIds = listOf(
            record.locationTrigger?.geofenceId ?: geofenceIdFor(record.id),
            outerGeofenceIdFor(record.id),
        )
        runCatching {
            Tasks.await(geofencingClient.removeGeofences(geofenceIds))
        }
        syncPassiveApproachMonitoring()
    }

    private fun deriveBlockingHealth(): LocationAlarmHealth? {
        return deriveLocationLookupBlockingHealth(requireBackgroundPermission = true)
    }

    private fun deriveLocationLookupBlockingHealth(
        requireBackgroundPermission: Boolean,
    ): LocationAlarmHealth? {
        if (!isForegroundLocationGranted()) {
            return LocationAlarmHealth.NO_FOREGROUND_PERMISSION
        }
        if (requireBackgroundPermission && !isBackgroundLocationGranted()) {
            return LocationAlarmHealth.NO_BACKGROUND_PERMISSION
        }
        if (!(locationManager?.isLocationEnabled ?: false)) {
            return LocationAlarmHealth.LOCATION_DISABLED
        }
        if (googleApiAvailability.isGooglePlayServicesAvailable(appContext) !=
            ConnectionResult.SUCCESS
        ) {
            return LocationAlarmHealth.PLAY_SERVICES_UNAVAILABLE
        }

        return null
    }

    private fun deriveWarningHealth(): LocationAlarmHealth {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !powerManager.isIgnoringBatteryOptimizations(appContext.packageName)
        ) {
            LocationAlarmHealth.BATTERY_RESTRICTED
        } else {
            LocationAlarmHealth.HEALTHY
        }
    }

    private fun isForegroundLocationGranted(): Boolean {
        return ContextCompat.checkSelfPermission(
            appContext,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun isBackgroundLocationGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(
                appContext,
                Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            isForegroundLocationGranted()
        }
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
            LOCATION_GEOFENCE_PENDING_INTENT_REQUEST_CODE,
            intent,
            flags,
        )
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
            LOCATION_PASSIVE_UPDATES_PENDING_INTENT_REQUEST_CODE,
            intent,
            flags,
        )
    }

    private fun syncPassiveApproachMonitoring() {
        val hasApproachingAlarms = store.getAll().any { record ->
            record.triggerKind == AlarmTriggerKind.LOCATION &&
                record.enabled &&
                record.locationTrigger?.approachState == LocationAlarmApproachState.APPROACHING
        }

        val pendingIntent = passiveLocationPendingIntent()
        if (!hasApproachingAlarms) {
            runCatching {
                fusedLocationClient.removeLocationUpdates(pendingIntent)
            }
            return
        }

        if (deriveLocationLookupBlockingHealth(requireBackgroundPermission = true) != null) {
            return
        }

        val request = LocationRequest.Builder(
            Priority.PRIORITY_PASSIVE,
            PASSIVE_LOCATION_UPDATE_INTERVAL_MS,
        )
            .setMinUpdateIntervalMillis(PASSIVE_LOCATION_UPDATE_INTERVAL_MS)
            .build()

        runCatching {
            Tasks.await(fusedLocationClient.requestLocationUpdates(request, pendingIntent))
        }.onFailure { error ->
            Log.w(logTag, "Unable to register passive approach listener: ${error.message}", error)
        }
    }

    companion object {
        private const val LOCATION_GEOFENCE_PENDING_INTENT_REQUEST_CODE = 42042
        private const val LOCATION_PASSIVE_UPDATES_PENDING_INTENT_REQUEST_CODE = 42043
        private const val DUPLICATE_TRIGGER_COOLDOWN_MS = 60_000L
        private const val OUTER_RADIUS_MULTIPLIER = 3
        private const val PASSIVE_LOCATION_UPDATE_INTERVAL_MS = 30_000L
        const val innerGeofenceIdPrefix = "location_alarm:"
        const val outerGeofenceIdPrefix = "location_alarm_outer:"

        fun geofenceIdFor(alarmId: String): String = "${innerGeofenceIdPrefix}$alarmId"

        fun outerGeofenceIdFor(alarmId: String): String = "${outerGeofenceIdPrefix}$alarmId"

        fun outerRadiusMetersFor(trigger: LocationAlarmRecord): Int {
            return trigger.radiusMeters * OUTER_RADIUS_MULTIPLIER
        }
    }

    private fun currentLocationSnapshot(
        requireBackgroundPermission: Boolean = true,
        allowActiveRequest: Boolean = true,
    ): Location? {
        if (deriveLocationLookupBlockingHealth(requireBackgroundPermission) != null) {
            return null
        }

        val lastLocation = runCatching {
            Tasks.await(fusedLocationClient.lastLocation)
        }.getOrNull()

        if (lastLocation != null || !allowActiveRequest) {
            return lastLocation
        }

        return runCatching {
            val tokenSource = CancellationTokenSource()
            Tasks.await(
                fusedLocationClient.getCurrentLocation(
                    Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                    tokenSource.token,
                ),
            )
        }.getOrNull()
    }

    private fun Location.distanceToLocationTrigger(trigger: LocationAlarmRecord): Float {
        val target = Location("location_alarm_target").apply {
            latitude = trigger.latitude
            longitude = trigger.longitude
        }

        return distanceTo(target)
    }
}
