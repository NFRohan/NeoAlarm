package dev.neoalarm.app.alarmengine

import android.content.Context
import android.location.Location
import android.util.Log
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.location.GeofenceStatusCodes

class LocationAlarmCoordinator(
    context: Context,
    private val store: AlarmStore,
) {
    private val logTag = "NeoAlarmLocation"
    private val appContext = context.applicationContext
    private val scheduler = AlarmScheduler(appContext, store)
    private val readinessProbe = LocationReadinessProbe(appContext)
    private val geofenceRegistrar = LocationGeofenceRegistrar(appContext)
    private val approachMonitor = LocationApproachMonitor(appContext, store, readinessProbe)
    private val rearmScheduler = LocationRearmScheduler(appContext, store)

    fun sync(record: AlarmRecord, force: Boolean = false): AlarmRecord {
        if (record.triggerKind != AlarmTriggerKind.LOCATION || record.locationTrigger == null) {
            return record
        }

        if (!force &&
            record.locationTrigger.health == LocationAlarmHealth.REARM_PENDING &&
            record.locationTrigger.nextRearmRetryAtEpochMillis != null &&
            System.currentTimeMillis() < record.locationTrigger.nextRearmRetryAtEpochMillis
        ) {
            rearmScheduler.sync()
            return record
        }

        if (!record.enabled) {
            Log.i(logTag, "Skipping geofence arm for disabled location alarm ${record.id}.")
            geofenceRegistrar.unregister(record)
            val persisted = persist(
                record.copy(
                    locationTrigger = clearLocationAlarmRegistration(record.locationTrigger),
                ),
            )
            approachMonitor.sync()
            rearmScheduler.sync()
            return persisted
        }

        val blockingHealth = deriveBlockingHealth()
        if (blockingHealth != null) {
            Log.w(
                logTag,
                "Cannot arm location alarm ${record.id}: " +
                    "health=${blockingHealth.id}, " +
                    "foregroundGranted=${readinessProbe.isForegroundLocationGranted()}, " +
                    "backgroundGranted=${readinessProbe.isBackgroundLocationGranted()}, " +
                    "locationEnabled=${readinessProbe.isLocationEnabled()}, " +
                    "playServices=${readinessProbe.playServicesStatus()}",
            )
            geofenceRegistrar.unregister(record)
            val persisted = if (shouldAutoRetryBlockingHealth(blockingHealth)) {
                persist(
                    record.copy(
                        locationTrigger = buildPendingRearmTrigger(
                            record.locationTrigger,
                        ),
                    ),
                )
            } else {
                persist(
                    record.copy(
                        locationTrigger = clearLocationAlarmRegistration(record.locationTrigger).copy(
                            health = blockingHealth,
                        ),
                    ),
                )
            }
            approachMonitor.sync()
            rearmScheduler.sync()
            return persisted
        }

        val geofenceId = LocationAlarmConfig.geofenceIdFor(record.id)
        val currentLocation = readinessProbe.currentLocationSnapshot()
        val distanceMeters = currentLocation?.distanceToLocationTrigger(record.locationTrigger)
        val healthAfterArm = if (
            distanceMeters != null &&
            distanceMeters <= record.locationTrigger.radiusMeters
        ) {
            LocationAlarmHealth.WAITING_FOR_EXIT
        } else {
            readinessProbe.warningHealth()
        }
        val approachStateAfterArm = when {
            distanceMeters != null &&
                distanceMeters > record.locationTrigger.radiusMeters &&
                distanceMeters <= LocationAlarmConfig.outerRadiusMetersFor(record.locationTrigger) -> {
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

        if (!force && geofenceRegistrar.isCurrentRegistrationReusable(record, geofenceId)) {
            Log.i(logTag, "Location alarm ${record.id} already armed; refreshing health only.")
            val persisted = persist(
                record.copy(
                    locationTrigger = record.locationTrigger.copy(
                        health = healthAfterArm,
                        geofenceId = geofenceId,
                        approachState = approachStateAfterArm,
                        approachEnteredAtEpochMillis = if (
                            approachStateAfterArm == LocationAlarmApproachState.APPROACHING
                        ) {
                            record.locationTrigger.approachEnteredAtEpochMillis ?: System.currentTimeMillis()
                        } else {
                            null
                        },
                        rearmRetryCount = 0,
                        nextRearmRetryAtEpochMillis = null,
                    ),
                ),
            )
            approachMonitor.sync()
            rearmScheduler.sync()
            return persisted
        }

        return try {
            Log.i(
                logTag,
                    "Arming location alarm ${record.id} " +
                    "radius=${record.locationTrigger.radiusMeters}",
            )
            geofenceRegistrar.unregister(record)
            geofenceRegistrar.register(record)
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
                        rearmRetryCount = 0,
                        nextRearmRetryAtEpochMillis = null,
                    ),
                ),
            )
            approachMonitor.sync()
            rearmScheduler.sync()
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
            val persisted = if (shouldAutoRetryApiCode(apiCode)) {
                persist(
                    record.copy(
                        locationTrigger = buildPendingRearmTrigger(
                            record.locationTrigger,
                        ),
                    ),
                )
            } else {
                persist(
                    record.copy(
                        locationTrigger = clearLocationAlarmRegistration(record.locationTrigger).copy(
                            health = LocationAlarmHealth.GEOFENCE_NOT_REGISTERED,
                        ),
                    ),
                )
            }
            approachMonitor.sync()
            rearmScheduler.sync()
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
            geofenceRegistrar.unregister(current)
        }
        scheduler.delete(id)
        approachMonitor.sync()
        rearmScheduler.sync()
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

        val currentLocation = readinessProbe.currentLocationSnapshot(allowActiveRequest = false)
        val distanceMeters = currentLocation?.distanceToLocationTrigger(trigger)?.toInt()
        val alreadyInsideRadius = distanceMeters != null && distanceMeters <= trigger.radiusMeters

        return mapOf(
            "health" to readinessProbe.warningHealth().id,
            "alreadyInsideRadius" to alreadyInsideRadius,
            "distanceMeters" to distanceMeters,
        )
    }

    fun currentLocationSnapshotMap(): Map<String, Any?>? {
        val location = readinessProbe.currentLocationSnapshot(
            requireBackgroundPermission = false,
        ) ?: return null
        return mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracyMeters" to location.accuracy.toDouble(),
        )
    }

    fun runForegroundFallbackCheck(): List<String> {
        val currentLocation = readinessProbe.currentLocationSnapshot(
            allowActiveRequest = false,
        ) ?: return emptyList()
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
                val outerRadiusMeters = LocationAlarmConfig.outerRadiusMetersFor(record.locationTrigger)
                if (distanceMeters > record.locationTrigger.radiusMeters) {
                    if (record.locationTrigger.health == LocationAlarmHealth.WAITING_FOR_EXIT) {
                        val updated = record.copy(
                            locationTrigger = record.locationTrigger.copy(
                                health = readinessProbe.warningHealth(),
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
            triggeredAtMillis - lastTransitionAt < LocationAlarmConfig.DUPLICATE_TRIGGER_COOLDOWN_MS
        ) {
            return false
        }

        val updated = current.copy(
            locationTrigger = clearLocationAlarmRegistration(current.locationTrigger).copy(
                health = LocationAlarmHealth.HEALTHY,
                lastTransitionAtEpochMillis = triggeredAtMillis,
                approachState = LocationAlarmApproachState.IDLE,
                approachEnteredAtEpochMillis = null,
                rearmRetryCount = 0,
                nextRearmRetryAtEpochMillis = null,
            ),
        )
        store.upsert(updated)
        geofenceRegistrar.unregister(current)
        approachMonitor.sync()
        rearmScheduler.sync()

        val triggered = scheduler.handleAlarmTriggered(alarmId) ?: return false
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
            approachMonitor.sync()
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
        approachMonitor.sync()
    }

    fun handleApproachZoneExited(alarmId: String) {
        val current = store.get(alarmId) ?: return
        val trigger = current.locationTrigger ?: return
        if (trigger.approachState != LocationAlarmApproachState.APPROACHING) {
            approachMonitor.sync()
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
        approachMonitor.sync()
    }

    fun handlePassiveLocationUpdate(
        location: Location,
        now: Long = System.currentTimeMillis(),
    ) {
        if (deriveBlockingHealth() != null) {
            approachMonitor.sync()
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

            if (distanceMeters > LocationAlarmConfig.outerRadiusMetersFor(trigger)) {
                handleApproachZoneExited(record.id)
                approachStateChanged = true
            }
        }

        if (!approachStateChanged) {
            approachMonitor.sync()
        }
    }

    fun handleGeofenceDeliveryError(apiCode: Int?) {
        Log.w(
            logTag,
            "Geofence delivery error apiCode=${apiCode ?: "n/a"}; marking armed alarms for repair.",
        )
        val now = System.currentTimeMillis()
        store.getAll().forEach { record ->
            if (record.triggerKind != AlarmTriggerKind.LOCATION ||
                !record.enabled ||
                record.locationTrigger == null
            ) {
                return@forEach
            }

            val nextTrigger = if (shouldAutoRetryApiCode(apiCode)) {
                buildPendingRearmTrigger(record.locationTrigger, now)
            } else {
                clearLocationAlarmRegistration(record.locationTrigger).copy(
                    health = LocationAlarmHealth.GEOFENCE_NOT_REGISTERED,
                )
            }
            store.upsert(record.copy(locationTrigger = nextTrigger))
        }
        approachMonitor.sync()
        rearmScheduler.sync()
    }

    private fun persist(record: AlarmRecord): AlarmRecord {
        store.upsert(record)
        return record
    }

    private fun deriveBlockingHealth(): LocationAlarmHealth? {
        return readinessProbe.blockingHealth(requireBackgroundPermission = true)
    }

    private fun buildPendingRearmTrigger(
        trigger: LocationAlarmRecord,
        now: Long = System.currentTimeMillis(),
    ): LocationAlarmRecord {
        val nextRetryCount = trigger.rearmRetryCount + 1
        return trigger.copy(
            geofenceId = null,
            registeredAtEpochMillis = null,
            approachState = LocationAlarmApproachState.IDLE,
            approachEnteredAtEpochMillis = null,
            health = LocationAlarmHealth.REARM_PENDING,
            rearmRetryCount = nextRetryCount,
            nextRearmRetryAtEpochMillis = now + LocationAlarmConfig.retryDelayMillisFor(
                nextRetryCount,
            ),
        )
    }

    private fun shouldAutoRetryBlockingHealth(health: LocationAlarmHealth): Boolean {
        return when (health) {
            LocationAlarmHealth.PLAY_SERVICES_UNAVAILABLE -> true
            LocationAlarmHealth.HEALTHY,
            LocationAlarmHealth.UNKNOWN,
            LocationAlarmHealth.REARM_PENDING,
            LocationAlarmHealth.NO_FOREGROUND_PERMISSION,
            LocationAlarmHealth.NO_BACKGROUND_PERMISSION,
            LocationAlarmHealth.LOCATION_DISABLED,
            LocationAlarmHealth.GEOFENCE_NOT_REGISTERED,
            LocationAlarmHealth.WAITING_FOR_EXIT,
            LocationAlarmHealth.BATTERY_RESTRICTED,
            LocationAlarmHealth.LOW_LOCATION_CONFIDENCE,
            -> false
        }
    }

    private fun shouldAutoRetryApiCode(apiCode: Int?): Boolean {
        return when (apiCode) {
            null -> true
            GeofenceStatusCodes.GEOFENCE_NOT_AVAILABLE,
            CommonStatusCodes.API_NOT_CONNECTED,
            CommonStatusCodes.NETWORK_ERROR,
            CommonStatusCodes.INTERNAL_ERROR,
            -> true

            else -> false
        }
    }

}
