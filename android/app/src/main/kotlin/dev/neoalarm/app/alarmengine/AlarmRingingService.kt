package dev.neoalarm.app.alarmengine

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.media.audiofx.LoudnessEnhancer
import android.os.Handler
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.UserManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.net.Uri
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import dev.neoalarm.app.MainActivity
import dev.neoalarm.app.R
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

class AlarmRingingService : Service() {
    private lateinit var alarmStore: AlarmStore
    private lateinit var ringSessionStore: RingSessionStore
    private lateinit var audioManager: AudioManager
    private lateinit var userManager: UserManager

    private var wakeLock: PowerManager.WakeLock? = null
    private var mediaPlayer: MediaPlayer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var currentSession: AlarmRingSession? = null
    private val rampHandler = Handler(Looper.getMainLooper())
    private var rampRunnable: Runnable? = null
    private var restoredAlarmVolume: Int? = null

    override fun onCreate() {
        super.onCreate()
        alarmStore = AlarmStore(applicationContext)
        ringSessionStore = RingSessionStore(applicationContext)
        audioManager = getSystemService(AudioManager::class.java)
        userManager = getSystemService(UserManager::class.java)
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

            ACTION_BEGIN_MISSION -> {
                beginMission()
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
        val sessions = ringSessionStore.getAll().toMutableList()
        val previousTopSession = sessions.lastOrNull(AlarmRingSession::isActive)
        val existingSession = sessions.lastOrNull { it.alarmId == alarmId }

        if (previousTopSession != null && previousTopSession.alarmId != alarmId) {
            val preparedSession = previousTopSession.preparedForPreemption()
            if (preparedSession != previousTopSession) {
                replaceSession(sessions, preparedSession)
            }
            AlarmSessionCoordinator.cancelMissionTimeout(
                applicationContext,
                previousTopSession.alarmId,
            )
        }

        sessions.removeAll { it.alarmId == alarmId }

        val alarm = alarmStore.get(alarmId)
        if (alarm == null) {
            persistSessions(sessions)
            if (currentSession?.alarmId == alarmId) {
                stopRingingFeedback()
                currentSession = null
                resumeNextActiveSessionOrStop()
            } else if (currentSession == null) {
                restoreIfNeeded()
            }
            return
        }

        AlarmSessionCoordinator.cancelSnooze(applicationContext, alarmId)
        AlarmSessionCoordinator.cancelMissionTimeout(applicationContext, alarmId)
        StepMissionTracker.stop()

        val session = existingSession?.resumeRinging() ?: AlarmRingSession.create(alarm)
        sessions.add(session)
        persistSessions(sessions)
        transitionToRingingSession(session)
    }

    private fun restoreIfNeeded() {
        val session = ringSessionStore.get()?.takeIf(AlarmRingSession::isRinging) ?: run {
            stopSelf()
            return
        }

        StepMissionTracker.stop()
        currentSession = session
        startForeground(NOTIFICATION_ID, buildNotification(session))
        acquireWakeLock()
        startFeedback()
    }

    private fun dismissActiveAlarm() {
        val session = currentSession ?: ringSessionStore.get()?.takeIf(AlarmRingSession::isActive) ?: run {
            stopSelf()
            return
        }

        val sessions = ringSessionStore.getAll()
            .filterNot { it.sessionId == session.sessionId }
        persistSessions(sessions)
        stopRingingFeedback()
        AlarmSessionCoordinator.cancelSnooze(applicationContext, session.alarmId)
        AlarmSessionCoordinator.cancelMissionTimeout(applicationContext, session.alarmId)
        StepMissionTracker.stop()
        currentSession = null
        resumeNextActiveSessionOrStop()
    }

    private fun snoozeActiveAlarm() {
        val session = currentSession ?: ringSessionStore.get()?.takeIf(AlarmRingSession::isActive) ?: run {
            stopSelf()
            return
        }

        if (!session.canSnooze) {
            return
        }

        val triggerAt = System.currentTimeMillis() + session.snoozeDurationMinutes * 60_000L
        val updatedSession = session.snoozedUntil(triggerAt)
        ringSessionStore.put(updatedSession)
        AlarmSessionCoordinator.scheduleSnooze(applicationContext, updatedSession)
        AlarmSessionCoordinator.cancelMissionTimeout(applicationContext, session.alarmId)
        StepMissionTracker.stop()
        stopRingingFeedback()
        currentSession = null
        resumeNextActiveSessionOrStop()
    }

    private fun beginMission() {
        val session = currentSession ?: ringSessionStore.get()?.takeIf(AlarmRingSession::isActive) ?: run {
            stopSelf()
            return
        }

        if (session.mission.spec.type == MissionSpec.TYPE_NONE) {
            return
        }

        val updatedSession = AlarmSessionCoordinator.activateMission(applicationContext, session)
        currentSession = updatedSession
        if (updatedSession.mission.spec.type == MissionSpec.TYPE_STEPS) {
            StepMissionTracker.ensureRunning(applicationContext, updatedSession)
        } else {
            StepMissionTracker.stop()
        }
        stopRingingFeedback()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun resumeNextActiveSessionOrStop() {
        val nextSession = ringSessionStore.get()?.takeIf(AlarmRingSession::isActive)
        if (nextSession == null) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }

        AlarmSessionCoordinator.cancelMissionTimeout(applicationContext, nextSession.alarmId)
        val resumedSession = nextSession.resumeRinging()
        ringSessionStore.put(resumedSession)
        transitionToRingingSession(resumedSession)
    }

    private fun transitionToRingingSession(session: AlarmRingSession) {
        stopRingingFeedback()
        currentSession = session
        startForeground(NOTIFICATION_ID, buildNotification(session))
        acquireWakeLock()
        startFeedback()
    }

    private fun stopRingingFeedback() {
        stopFeedback()
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
    }

    private fun persistSessions(sessions: List<AlarmRingSession>) {
        if (sessions.isEmpty()) {
            ringSessionStore.clear()
            return
        }
        ringSessionStore.putAll(sessions)
    }

    private fun replaceSession(
        sessions: MutableList<AlarmRingSession>,
        updatedSession: AlarmRingSession,
    ) {
        val index = sessions.indexOfFirst { it.sessionId == updatedSession.sessionId }
        if (index >= 0) {
            sessions[index] = updatedSession
        } else {
            sessions.add(updatedSession)
        }
    }

    private fun startFeedback() {
        startPlayback()
        startVibration()
    }

    private fun stopFeedback() {
        stopRamp()
        loudnessEnhancer?.release()
        loudnessEnhancer = null
        mediaPlayer?.apply {
            setOnPreparedListener(null)
            setOnErrorListener(null)
            stopSafely()
            reset()
            release()
        }
        mediaPlayer = null
        restoreAlarmVolumeIfNeeded()
        vibrator().cancel()
    }

    private fun startPlayback() {
        if (mediaPlayer?.isPlaying == true) {
            return
        }

        val activeAlarm = currentSession?.alarmId?.let(alarmStore::get)
        val toneUri = resolveToneUri(activeAlarm?.ringtoneId ?: "system_alarm")
        val shouldRamp = activeAlarm?.volumeRampEnabled == true
        val shouldEnableExtraLoud = activeAlarm?.extraLoudEnabled == true
        val targetVolume = 1f
        val startingVolume = if (shouldRamp) 0.12f else targetVolume

        if (shouldRamp) {
            maybeApplyAlarmVolumeFloor()
        } else {
            restoreAlarmVolumeIfNeeded()
        }

        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
            )
            isLooping = true
            setVolume(startingVolume, startingVolume)
            maybeAttachLoudnessEnhancer(this, shouldEnableExtraLoud)
            setOnPreparedListener { player ->
                player.start()
                if (shouldRamp) {
                    startVolumeRamp(player, startingVolume, targetVolume)
                }
            }
            setOnErrorListener { _, _, _ ->
                stopFeedback()
                false
            }
            try {
                when {
                    toneUri == null -> setDataSourceToFallback(this)
                    toneUri.scheme == ContentResolver.SCHEME_ANDROID_RESOURCE -> {
                        setDataSource(applicationContext, toneUri)
                    }

                    else -> setDataSource(applicationContext, toneUri)
                }
                prepareAsync()
            } catch (_: Exception) {
                try {
                    reset()
                    setVolume(startingVolume, startingVolume)
                    setDataSourceToFallback(this)
                    prepareAsync()
                } catch (_: Exception) {
                    release()
                    mediaPlayer = null
                    restoreAlarmVolumeIfNeeded()
                }
            }
        }
    }

    private fun startVibration() {
        val effect = VibrationEffect.createWaveform(longArrayOf(0, 700, 500), 0)
        vibrator().vibrate(effect)
    }

    private fun resolveToneUri(ringtoneId: String): Uri? {
        if (!isUserUnlocked()) {
            return fallbackToneUri()
        }

        val ringtoneType = when (ringtoneId) {
            "system_notification" -> RingtoneManager.TYPE_NOTIFICATION
            else -> RingtoneManager.TYPE_ALARM
        }

        return RingtoneManager.getActualDefaultRingtoneUri(applicationContext, ringtoneType)
            ?: RingtoneManager.getDefaultUri(ringtoneType)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: fallbackToneUri()
    }

    private fun fallbackToneUri(): Uri {
        return Uri.parse("android.resource://$packageName/${R.raw.direct_boot_alarm_fallback}")
    }

    private fun maybeAttachLoudnessEnhancer(
        player: MediaPlayer,
        shouldEnable: Boolean,
    ) {
        loudnessEnhancer?.release()
        loudnessEnhancer = null

        if (!shouldEnable || !isSpeakerOutputActive()) {
            return
        }

        try {
            loudnessEnhancer = LoudnessEnhancer(player.audioSessionId).apply {
                setTargetGain(EXTRA_LOUD_TARGET_GAIN_MB)
                enabled = true
            }
        } catch (_: Exception) {
            loudnessEnhancer?.release()
            loudnessEnhancer = null
        }
    }

    private fun setDataSourceToFallback(player: MediaPlayer) {
        player.setDataSource(applicationContext, fallbackToneUri())
    }

    private fun startVolumeRamp(
        player: MediaPlayer,
        startingVolume: Float,
        targetVolume: Float,
    ) {
        stopRamp()
        val startAt = System.currentTimeMillis()
        val durationMillis = 25_000L
        val minVolume = startingVolume.coerceIn(0f, 1f)
        val maxVolume = targetVolume.coerceIn(minVolume, 1f)

        val runnable = object : Runnable {
            override fun run() {
                if (mediaPlayer !== player || !player.isPlaying) {
                    return
                }

                val elapsed = System.currentTimeMillis() - startAt
                val progress = min(1f, elapsed.toFloat() / durationMillis.toFloat())
                val currentVolume = minVolume + (maxVolume - minVolume) * progress
                player.setVolume(currentVolume, currentVolume)

                if (progress < 1f) {
                    rampHandler.postDelayed(this, 750L)
                }
            }
        }

        rampRunnable = runnable
        rampHandler.post(runnable)
    }

    private fun stopRamp() {
        rampRunnable?.let(rampHandler::removeCallbacks)
        rampRunnable = null
    }

    private fun maybeApplyAlarmVolumeFloor() {
        val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        val minimumAudibleFloor = max(1, ceil(maxVolume * 0.35).toInt())

        if (currentVolume >= minimumAudibleFloor) {
            restoreAlarmVolumeIfNeeded()
            return
        }

        if (restoredAlarmVolume == null) {
            restoredAlarmVolume = currentVolume
        }

        audioManager.setStreamVolume(
            AudioManager.STREAM_ALARM,
            minimumAudibleFloor,
            0,
        )
    }

    private fun restoreAlarmVolumeIfNeeded() {
        val previousVolume = restoredAlarmVolume ?: return
        audioManager.setStreamVolume(
            AudioManager.STREAM_ALARM,
            previousVolume,
            0,
        )
        restoredAlarmVolume = null
    }

    private fun isUserUnlocked(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            userManager.isUserUnlocked
        } else {
            true
        }
    }

    private fun isSpeakerOutputActive(): Boolean {
        val outputs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        if (outputs.isEmpty()) {
            return true
        }

        if (outputs.any(::isPrivateListeningRoute)) {
            return false
        }

        return outputs.any(::isSpeakerRoute)
    }

    private fun isSpeakerRoute(device: AudioDeviceInfo): Boolean {
        return when (device.type) {
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER_SAFE,
            -> true

            else -> false
        }
    }

    private fun isPrivateListeningRoute(device: AudioDeviceInfo): Boolean {
        return when (device.type) {
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_BLE_SPEAKER,
            AudioDeviceInfo.TYPE_HEARING_AID,
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_LINE_ANALOG,
            AudioDeviceInfo.TYPE_LINE_DIGITAL,
            AudioDeviceInfo.TYPE_AUX_LINE,
            -> true

            else -> false
        }
    }

    private fun MediaPlayer.stopSafely() {
        try {
            if (isPlaying) {
                stop()
            }
        } catch (_: IllegalStateException) {
        }
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
        val launchIntent = Intent()
            .setClass(this, MainActivity::class.java)
            .setPackage(packageName)
            .apply {
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
                when (session.mission.spec.type) {
                    MissionSpec.TYPE_MATH -> {
                        val count =
                            MissionSpec.normalizeMathProblemCount(session.mission.spec.mathProblemCount)
                        "Solve $count math ${if (count == 1) "problem" else "problems"} to dismiss"
                    }

                    MissionSpec.TYPE_STEPS -> {
                        val goal = MissionSpec.normalizeStepGoal(session.mission.spec.stepGoal)
                        "Walk $goal steps to dismiss"
                    }

                    else -> "Alarm is ringing"
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
        private const val EXTRA_LOUD_TARGET_GAIN_MB = 200
        const val ACTION_SHOW_ACTIVE_ALARM = "dev.neoalarm.app.SHOW_ACTIVE_ALARM"
        private const val ACTION_START = "dev.neoalarm.app.START_ACTIVE_ALARM"
        private const val ACTION_DISMISS = "dev.neoalarm.app.DISMISS_ACTIVE_ALARM"
        private const val ACTION_SNOOZE = "dev.neoalarm.app.SNOOZE_ACTIVE_ALARM"
        private const val ACTION_BEGIN_MISSION = "dev.neoalarm.app.BEGIN_MISSION"

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

        fun beginMission(context: Context) {
            context.startService(
                Intent(context, AlarmRingingService::class.java).apply {
                    action = ACTION_BEGIN_MISSION
                },
            )
        }
    }
}

