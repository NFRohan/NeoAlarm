package dev.alarmsoss.alarms_oss.alarmengine

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
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
    private val appContext = context.applicationContext
    private val store = AlarmStore(appContext)
    private val ringSessionStore = RingSessionStore(appContext)
    private val scheduler = AlarmScheduler(appContext, store)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getStatus" -> result.success(
                    mapOf(
                        "canScheduleExactAlarms" to scheduler.canScheduleExactAlarms(),
                        "notificationsEnabled" to NotificationManagerCompat.from(appContext)
                            .areNotificationsEnabled(),
                        "timezoneId" to ZoneId.systemDefault().id,
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

                "getActiveSession" -> result.success(ringSessionStore.get()?.toChannelMap())

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
                    AlarmRingingService.dismiss(appContext)
                    result.success(null)
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
                        val hostActivity = activity
                            ?: throw IllegalStateException("Activity unavailable for notification permission request.")
                        val granted = ContextCompat.checkSelfPermission(
                            hostActivity,
                            Manifest.permission.POST_NOTIFICATIONS,
                        ) == PackageManager.PERMISSION_GRANTED

                        if (!granted) {
                            ActivityCompat.requestPermissions(
                                hostActivity,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
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

                else -> result.notImplemented()
            }
        } catch (error: ExactAlarmPermissionException) {
            result.error("exact_alarm_denied", error.message, null)
        } catch (error: Exception) {
            result.error("alarm_engine_error", error.message, null)
        }
    }

    companion object {
        private const val REQUEST_NOTIFICATIONS_CODE = 1001
    }
}
