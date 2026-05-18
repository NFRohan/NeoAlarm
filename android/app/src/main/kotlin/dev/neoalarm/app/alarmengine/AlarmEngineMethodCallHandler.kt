package dev.neoalarm.app.alarmengine

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.time.ZoneId

class AlarmEngineMethodCallHandler(
    context: Context,
    activity: Activity?,
) : MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private val store = AlarmStore(appContext)
    private val ringSessionStore = RingSessionStore(appContext)
    private val scheduler = AlarmScheduler(appContext, store)
    private val locationAlarmCoordinator = LocationAlarmCoordinator(appContext, store)
    private val workerExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val permissionCommands = AlarmPermissionCommandHandler(
        context = appContext,
        activity = activity,
        scheduler = scheduler,
        ringSessionStore = ringSessionStore,
    )
    private val toneCommands = ToneCommandHandler(
        context = appContext,
        activity = activity,
        workerExecutor = workerExecutor,
        mainHandler = mainHandler,
    )

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getStatus" -> result.success(permissionCommands.statusMap())

                "getStartupContext" -> result.success(permissionCommands.startupContextMap())

                "listAlarms" -> result.success(
                    store.getAll().map(::alarmToChannelMap),
                )

                "listAvailableTimezones" -> result.success(
                    ZoneId.getAvailableZoneIds().sorted(),
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
                    if (record.triggerKind == AlarmTriggerKind.LOCATION) {
                        runOnWorker(result) {
                            val updated = locationAlarmCoordinator.sync(store.upsert(record), force = true)
                            mainHandler.post {
                                result.success(alarmToChannelMap(updated))
                            }
                        }
                    } else {
                        result.success(alarmToChannelMap(scheduler.upsert(record)))
                    }
                }

                "setAlarmEnabled" -> {
                    val raw = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Alarm toggle payload missing.")
                    val id = raw["id"] as? String
                        ?: throw IllegalArgumentException("Alarm id missing.")
                    val enabled = raw["enabled"] as? Boolean
                        ?: throw IllegalArgumentException("Enabled flag missing.")
                    val updated = scheduler.updateEnabled(id, enabled)
                    if (updated.triggerKind == AlarmTriggerKind.LOCATION) {
                        runOnWorker(result) {
                            val synced = locationAlarmCoordinator.sync(updated, force = true)
                            mainHandler.post {
                                result.success(alarmToChannelMap(synced))
                            }
                        }
                    } else {
                        result.success(alarmToChannelMap(updated))
                    }
                }

                "skipNextOccurrence" -> {
                    val raw = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Skip-next payload missing.")
                    val id = raw["id"] as? String
                        ?: throw IllegalArgumentException("Alarm id missing.")
                    result.success(alarmToChannelMap(scheduler.skipNextOccurrence(id)))
                }

                "clearSkippedOccurrence" -> {
                    val raw = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Clear-skip payload missing.")
                    val id = raw["id"] as? String
                        ?: throw IllegalArgumentException("Alarm id missing.")
                    result.success(alarmToChannelMap(scheduler.clearSkippedOccurrence(id)))
                }

                "refreshLocationAlarm" -> {
                    val raw = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Location-refresh payload missing.")
                    val id = raw["id"] as? String
                        ?: throw IllegalArgumentException("Alarm id missing.")
                    val current = store.get(id)
                        ?: throw IllegalArgumentException("Alarm not found: $id")
                    if (current.triggerKind != AlarmTriggerKind.LOCATION) {
                        throw IllegalStateException("Refresh is only available for location alarms.")
                    }
                    runOnWorker(result) {
                        val updated = locationAlarmCoordinator.sync(current, force = true)
                        mainHandler.post {
                            result.success(alarmToChannelMap(updated))
                        }
                    }
                }

                "refreshLocationAlarms" -> {
                    runOnWorker(result) {
                        locationAlarmCoordinator.syncAll()
                        mainHandler.post {
                            result.success(null)
                        }
                    }
                }

                "getCurrentLocationSnapshot" -> {
                    runOnWorker(result) {
                        val snapshot = locationAlarmCoordinator.currentLocationSnapshotMap()
                        mainHandler.post {
                            result.success(snapshot)
                        }
                    }
                }

                "listCustomTones" -> {
                    result.success(toneCommands.listToneMaps())
                }

                "importCustomTone" -> {
                    toneCommands.importTone(result)
                }

                "deleteCustomTone" -> {
                    val raw = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Delete tone payload missing.")
                    val id = raw["id"] as? String
                        ?: throw IllegalArgumentException("Tone id missing.")
                    val affectedAlarmIds = toneCommands.deleteTone(id)
                    result.success(affectedAlarmIds)
                }

                "deleteAlarm" -> {
                    val raw = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Delete payload missing.")
                    val id = raw["id"] as? String
                        ?: throw IllegalArgumentException("Alarm id missing.")
                    val existing = store.get(id)
                    if (existing?.triggerKind == AlarmTriggerKind.LOCATION) {
                        runOnWorker(result) {
                            locationAlarmCoordinator.delete(id)
                            mainHandler.post {
                                result.success(null)
                            }
                        }
                    } else {
                        scheduler.delete(id)
                        result.success(null)
                    }
                }

                "rescheduleAll" -> {
                    runOnWorker(result) {
                        scheduler.rescheduleAll()
                        locationAlarmCoordinator.syncAll()
                        mainHandler.post {
                            result.success(null)
                        }
                    }
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
                    permissionCommands.requestExactAlarmPermission()
                    result.success(null)
                }

                "requestNotificationPermission" -> {
                    permissionCommands.requestNotificationPermission()
                    result.success(null)
                }

                "requestBatteryOptimizationExemption" -> {
                    permissionCommands.requestBatteryOptimizationExemption()
                    result.success(null)
                }

                "requestCameraPermission" -> {
                    permissionCommands.requestCameraPermission()
                    result.success(null)
                }

                "requestActivityRecognitionPermission" -> {
                    permissionCommands.requestActivityRecognitionPermission()
                    result.success(null)
                }

                "requestForegroundLocationPermission" -> {
                    permissionCommands.requestForegroundLocationPermission()
                    result.success(null)
                }

                "requestBackgroundLocationPermission" -> {
                    permissionCommands.requestBackgroundLocationPermission()
                    result.success(null)
                }

                "evaluateLocationTrigger" -> {
                    val raw = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Location trigger payload missing.")
                    val trigger = LocationAlarmRecord.fromChannelMap(raw)
                    runOnWorker(result) {
                        val diagnostics = locationAlarmCoordinator.evaluateDraft(trigger)
                        mainHandler.post {
                            result.success(diagnostics)
                        }
                    }
                }

                "runLocationAlarmForegroundCheck" -> {
                    runOnWorker(result) {
                        locationAlarmCoordinator.runForegroundFallbackCheck()
                        mainHandler.post {
                            result.success(null)
                        }
                    }
                }

                "openLocationSettings" -> {
                    permissionCommands.openLocationSettings()
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

    private fun activeSession(): AlarmRingSession? {
        return ringSessionStore.get()?.takeIf(AlarmRingSession::isActive)
    }

    private fun alarmToChannelMap(record: AlarmRecord): Map<String, Any?> {
        return record.toChannelMap() + toneCommands.channelFieldsFor(record)
    }

    fun dispose() {
        toneCommands.dispose()
        workerExecutor.shutdownNow()
    }

    private fun runOnWorker(
        result: MethodChannel.Result,
        task: () -> Unit,
    ) {
        workerExecutor.execute {
            try {
                task()
            } catch (error: ExactAlarmPermissionException) {
                mainHandler.post {
                    result.error("exact_alarm_denied", error.message, null)
                }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("alarm_engine_error", error.message, null)
                }
            }
        }
    }
}

