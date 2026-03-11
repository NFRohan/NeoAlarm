package dev.neoalarm.app.alarmengine

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel

class ActiveSessionStreamHandler(
    context: Context,
) : EventChannel.StreamHandler {
    private val appContext = context.applicationContext
    private val mainExecutor = ContextCompat.getMainExecutor(appContext)
    private val ringSessionStore = RingSessionStore(appContext)

    private var eventSink: EventChannel.EventSink? = null
    private var listener: SharedPreferences.OnSharedPreferenceChangeListener? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        listener?.let(ringSessionStore::unregisterListener)
        eventSink = events
        emitCurrentSession()
        listener = ringSessionStore.registerListener { session ->
            emitSession(session)
        }
    }

    override fun onCancel(arguments: Any?) {
        listener?.let(ringSessionStore::unregisterListener)
        listener = null
        eventSink = null
    }

    private fun emitCurrentSession() {
        emitSession(ringSessionStore.get()?.takeIf(AlarmRingSession::isActive))
    }

    private fun emitSession(session: AlarmRingSession?) {
        mainExecutor.execute {
            eventSink?.success(session?.takeIf(AlarmRingSession::isActive)?.toChannelMap())
        }
    }
}
