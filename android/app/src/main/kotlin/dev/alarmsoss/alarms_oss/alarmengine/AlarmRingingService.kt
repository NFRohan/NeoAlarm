package dev.alarmsoss.alarms_oss.alarmengine

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.media.AudioAttributes
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.net.Uri
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import dev.alarmsoss.alarms_oss.MainActivity

class AlarmRingingService : Service() {
    private lateinit var alarmStore: AlarmStore
    private lateinit var ringSessionStore: RingSessionStore
    private lateinit var alarmManager: AlarmManager

    private var wakeLock: PowerManager.WakeLock? = null
    private var ringtone: Ringtone? = null
    private var currentSession: AlarmRingSession? = null

    override fun onCreate() {
        super.onCreate()
        alarmStore = AlarmStore(applicationContext)
        ringSessionStore = RingSessionStore(applicationContext)
        alarmManager = getSystemService(AlarmManager::class.java)
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_DISMISS -> {
                dismissActiveAlarm()
                START_NOT_STICKY
            }

            ACTION_START -> {
                val alarmId = intent.getStringExtra(EXTRA_ALARM_ID)
                if (alarmId.isNullOrBlank()) {
                    stopSelf()
                    START_NOT_STICKY
                } else {
                    startAlarm(alarmId)
                    START_STICKY
                }
            }

            ACTION_SNOOZE -> {
                snoozeActiveAlarm()
                START_NOT_STICKY
            }

            else -> {
                restoreIfNeeded()
                if (currentSession == null) START_NOT_STICKY else START_STICKY
            }
        }
    }

    override fun onDestroy() {
        stopFeedback()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startAlarm(alarmId: String) {
        val alarm = alarmStore.get(alarmId) ?: run {
            dismissActiveAlarm(clearSession = true)
            return
        }

        cancelSnooze(alarmId)

        val session = ringSessionStore.get()
            ?.takeIf { it.alarmId == alarmId }
            ?.resumeRinging()
            ?: AlarmRingSession.create(alarm)

        ringSessionStore.put(session)
        currentSession = session
        startForeground(NOTIFICATION_ID, buildNotification(session))
        acquireWakeLock()
        startFeedback()
    }

    private fun restoreIfNeeded() {
        val session = ringSessionStore.get()?.takeIf(AlarmRingSession::isRinging) ?: run {
            stopSelf()
            return
        }

        currentSession = session
        startForeground(NOTIFICATION_ID, buildNotification(session))
        acquireWakeLock()
        startFeedback()
    }

    private fun dismissActiveAlarm(clearSession: Boolean = true) {
        stopFeedback()
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        currentSession?.alarmId?.let(::cancelSnooze)
        currentSession = null
        if (clearSession) {
            ringSessionStore.clear()
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun snoozeActiveAlarm() {
        val session = currentSession ?: ringSessionStore.get()?.takeIf(AlarmRingSession::isRinging) ?: run {
            stopSelf()
            return
        }

        if (!session.canSnooze) {
            return
        }

        val triggerAt = System.currentTimeMillis() + session.snoozeDurationMinutes * 60_000L
        val updatedSession = session.snoozedUntil(triggerAt)
        ringSessionStore.put(updatedSession)
        scheduleSnooze(updatedSession)
        stopFeedback()
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        currentSession = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun startFeedback() {
        startRingtone()
        startVibration()
    }

    private fun stopFeedback() {
        ringtone?.stop()
        ringtone = null
        vibrator().cancel()
    }

    private fun startRingtone() {
        if (ringtone?.isPlaying == true) {
            return
        }

        val activeAlarm = currentSession?.alarmId?.let(alarmStore::get)
        val toneUri = resolveToneUri(activeAlarm?.ringtoneId ?: "system_alarm")
            ?: return

        ringtone = RingtoneManager.getRingtone(applicationContext, toneUri)?.apply {
            audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            isLooping = true
            play()
        }
    }

    private fun startVibration() {
        val effect = VibrationEffect.createWaveform(longArrayOf(0, 700, 500), 0)
        vibrator().vibrate(effect)
    }

    private fun resolveToneUri(ringtoneId: String): Uri? {
        val ringtoneType = when (ringtoneId) {
            "system_notification" -> RingtoneManager.TYPE_NOTIFICATION
            else -> RingtoneManager.TYPE_ALARM
        }

        return RingtoneManager.getActualDefaultRingtoneUri(applicationContext, ringtoneType)
            ?: RingtoneManager.getDefaultUri(ringtoneType)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) {
            return
        }

        val powerManager = getSystemService(PowerManager::class.java)
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "$packageName:active_alarm",
        ).apply {
            setReferenceCounted(false)
            acquire(WAKE_LOCK_TIMEOUT_MS)
        }
    }

    private fun vibrator(): Vibrator {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as Vibrator
        }
    }

    private fun buildNotification(session: AlarmRingSession): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_SHOW_ACTIVE_ALARM
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        val launchPendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(session.alarmLabel)
            .setContentText(
                if (session.mission.spec.type == MissionSpec.TYPE_MATH) {
                    "Solve the math mission to dismiss"
                } else {
                    "Alarm is ringing"
                },
            )
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(launchPendingIntent)
            .setFullScreenIntent(launchPendingIntent, true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    private fun ensureNotificationChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) {
            return
        }

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Active alarms",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Foreground notification used while an alarm is actively ringing."
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setSound(null, null)
            enableVibration(false)
        }

        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val CHANNEL_ID = "active_alarm"
        private const val NOTIFICATION_ID = 42001
        private const val EXTRA_ALARM_ID = "alarm_id"
        private const val WAKE_LOCK_TIMEOUT_MS = 30 * 60 * 1000L
        const val ACTION_SHOW_ACTIVE_ALARM = "dev.alarmsoss.alarms_oss.SHOW_ACTIVE_ALARM"
        private const val ACTION_START = "dev.alarmsoss.alarms_oss.START_ACTIVE_ALARM"
        private const val ACTION_DISMISS = "dev.alarmsoss.alarms_oss.DISMISS_ACTIVE_ALARM"
        private const val ACTION_SNOOZE = "dev.alarmsoss.alarms_oss.SNOOZE_ACTIVE_ALARM"

        fun start(context: Context, alarmId: String) {
            ContextCompat.startForegroundService(
                context,
                Intent(context, AlarmRingingService::class.java).apply {
                    action = ACTION_START
                    putExtra(EXTRA_ALARM_ID, alarmId)
                },
            )
        }

        fun dismiss(context: Context) {
            context.startService(
                Intent(context, AlarmRingingService::class.java).apply {
                    action = ACTION_DISMISS
                },
            )
        }

        fun snooze(context: Context) {
            context.startService(
                Intent(context, AlarmRingingService::class.java).apply {
                    action = ACTION_SNOOZE
                },
            )
        }
    }

    private fun scheduleSnooze(session: AlarmRingSession) {
        val triggerAt = session.nextSnoozeAtEpochMillis ?: return
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAt,
            buildSnoozeOperation(session.alarmId),
        )
    }

    private fun cancelSnooze(alarmId: String) {
        alarmManager.cancel(buildSnoozeOperation(alarmId))
    }

    private fun buildSnoozeOperation(alarmId: String): PendingIntent {
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra(AlarmReceiver.EXTRA_ALARM_ID, alarmId)
            putExtra(AlarmReceiver.EXTRA_IS_SNOOZE, true)
        }

        return PendingIntent.getBroadcast(
            this,
            "$alarmId:snooze".hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
