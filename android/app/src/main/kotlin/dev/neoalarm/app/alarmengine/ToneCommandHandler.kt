package dev.neoalarm.app.alarmengine

import android.content.Context
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import android.os.Handler
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService

internal class ToneCommandHandler(
    context: Context,
    activity: android.app.Activity?,
    private val workerExecutor: ExecutorService,
    private val mainHandler: Handler,
) {
    private val appContext = context.applicationContext
    private val toneLibraryStore = ToneLibraryStore(appContext)
    private val toneLibraryManager = ToneLibraryManager(appContext, toneLibraryStore)
    private var pendingToneImportResult: MethodChannel.Result? = null
    private val toneImportLauncher =
        (activity as? ComponentActivity)?.registerForActivityResult(
            ActivityResultContracts.OpenDocument(),
        ) { uri ->
            val callback = pendingToneImportResult ?: return@registerForActivityResult
            pendingToneImportResult = null

            if (uri == null) {
                callback.success(null)
                return@registerForActivityResult
            }

            workerExecutor.execute {
                try {
                    val tone = toneLibraryManager.importTone(uri)
                    mainHandler.post {
                        callback.success(tone)
                    }
                } catch (error: ToneImportException) {
                    mainHandler.post {
                        callback.error("tone_import_error", error.message, null)
                    }
                } catch (error: Exception) {
                    mainHandler.post {
                        callback.error("tone_import_error", "Unable to import the selected tone.", null)
                    }
                }
            }
        }

    fun listToneMaps(): List<Map<String, Any?>> {
        return toneLibraryManager.listToneMaps()
    }

    fun importTone(result: MethodChannel.Result) {
        if (toneImportLauncher == null) {
            throw IllegalStateException("Tone picker unavailable.")
        }
        if (pendingToneImportResult != null) {
            throw IllegalStateException("Tone import already in progress.")
        }
        pendingToneImportResult = result
        toneImportLauncher.launch(arrayOf("audio/mpeg", "audio/x-wav", "audio/wav"))
    }

    fun deleteTone(id: String): List<String> {
        return toneLibraryManager.deleteTone(id)
    }

    fun channelFieldsFor(record: AlarmRecord): Map<String, Any?> {
        val customTone = record.customToneId?.let(toneLibraryStore::get)
        val customToneHealthy = if (record.ringtoneId == "custom_tone") {
            customTone?.let(toneLibraryManager::isHealthy) ?: false
        } else {
            true
        }
        val customToneName = if (record.ringtoneId == "custom_tone") {
            customTone?.displayName ?: "Missing custom tone"
        } else {
            null
        }

        return mapOf(
            "customToneId" to record.customToneId,
            "customToneName" to customToneName,
            "customToneHealthy" to customToneHealthy,
        )
    }

    fun dispose() {
        val callback = pendingToneImportResult ?: return
        pendingToneImportResult = null
        callback.error("tone_import_cancelled", "Tone import was cancelled.", null)
    }
}
