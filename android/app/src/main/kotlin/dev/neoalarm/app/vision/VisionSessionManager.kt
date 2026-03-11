package dev.neoalarm.app.vision

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import dev.neoalarm.app.alarmengine.AlarmSessionCoordinator
import dev.neoalarm.app.alarmengine.AlarmRingingService
import dev.neoalarm.app.alarmengine.MissionSpec
import dev.neoalarm.app.alarmengine.QrMissionTrackingState
import dev.neoalarm.app.alarmengine.RingSessionStore
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class VisionSessionManager(
    context: Context,
    private val lifecycleOwner: LifecycleOwner,
) : EventChannel.StreamHandler {
    private val appContext = context.applicationContext
    private val mainExecutor = ContextCompat.getMainExecutor(appContext)
    private val ringSessionStore = RingSessionStore(appContext)
    private val cameraExecutor = Executors.newSingleThreadExecutor()
    private val barcodeScanner = BarcodeScanning.getClient(
        BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .build(),
    )

    private val isProcessingFrame = AtomicBoolean(false)

    private var cameraProvider: ProcessCameraProvider? = null
    private var boundConfig: VisionSessionConfig? = null
    private var eventSink: EventChannel.EventSink? = null
    private var previewView: PreviewView? = null
    private var sessionConfig: VisionSessionConfig? = null
    private var lastMissionActivityValue: String? = null
    private var lastEmittedValue: String? = null
    private var lastEmittedAtEpochMillis = 0L
    private var disposed = false

    fun attachPreviewView(previewView: PreviewView) {
        if (disposed) {
            return
        }
        this.previewView = previewView
        bindIfPossible()
    }

    fun detachPreviewView(previewView: PreviewView) {
        if (this.previewView !== previewView) {
            return
        }

        this.previewView = null
        unbindCamera()
    }

    fun startQrRegistration() {
        val nextConfig = VisionSessionConfig(mode = VisionSessionMode.QR_REGISTRATION)
        if (sessionConfig != nextConfig) {
            sessionConfig = nextConfig
            resetSessionSignals()
        }
        bindIfPossible()
    }

    fun startQrMission(targetValue: String) {
        val normalizedTargetValue = MissionSpec.normalizeQrTargetValue(targetValue)
            ?: throw IllegalArgumentException("QR target value is required.")

        val nextConfig = VisionSessionConfig(
            mode = VisionSessionMode.QR_MISSION,
            expectedTargetValue = normalizedTargetValue,
        )
        if (sessionConfig != nextConfig) {
            sessionConfig = nextConfig
            resetSessionSignals()
        }
        bindIfPossible()
    }

    fun stopSession() {
        sessionConfig = null
        resetSessionSignals()
        unbindCamera()
    }

    fun dispose() {
        disposed = true
        stopSession()
        eventSink = null
        barcodeScanner.close()
        cameraExecutor.shutdownNow()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun bindIfPossible() {
        if (disposed) {
            return
        }
        val activeConfig = sessionConfig ?: return

        if (!appContext.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
            if (activeConfig.mode == VisionSessionMode.QR_MISSION) {
                updateActiveQrMissionState(QrMissionTrackingState.UNSUPPORTED_CAMERA)
            }
            emitError("camera_unavailable", "This device does not report a usable camera.")
            return
        }

        if (!isCameraPermissionGranted()) {
            if (activeConfig.mode == VisionSessionMode.QR_MISSION) {
                updateActiveQrMissionState(QrMissionTrackingState.MISSING_PERMISSION)
            }
            emitError("camera_permission_missing", "Camera permission is required for QR scanning.")
            return
        }

        if (activeConfig.mode == VisionSessionMode.QR_MISSION) {
            val nextState = if (activeConfig.expectedTargetValue == null) {
                QrMissionTrackingState.TARGET_MISSING
            } else {
                QrMissionTrackingState.AWAITING_SCAN
            }
            updateActiveQrMissionState(nextState)
        }

        val resolvedPreviewView = previewView ?: return
        if (cameraProvider != null &&
            boundConfig == activeConfig &&
            this.previewView === resolvedPreviewView
        ) {
            emitEvent(
                mapOf(
                    "type" to EVENT_READY,
                    "mode" to activeConfig.mode.id,
                ),
            )
            return
        }

        val providerFuture = ProcessCameraProvider.getInstance(appContext)
        providerFuture.addListener(
            {
                if (disposed || sessionConfig != activeConfig || previewView !== resolvedPreviewView) {
                    return@addListener
                }
                val provider = providerFuture.get()
                if (cameraProvider === provider &&
                    boundConfig == activeConfig &&
                    previewView === resolvedPreviewView
                ) {
                    emitEvent(
                        mapOf(
                            "type" to EVENT_READY,
                            "mode" to activeConfig.mode.id,
                        ),
                    )
                    return@addListener
                }
                cameraProvider = provider
                provider.unbindAll()

                val preview = Preview.Builder().build().apply {
                    surfaceProvider = resolvedPreviewView.surfaceProvider
                }

                val analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                    .apply {
                        setAnalyzer(cameraExecutor, ::analyzeImage)
                    }

                provider.bindToLifecycle(
                    lifecycleOwner,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    analysis,
                )
                boundConfig = activeConfig

                emitEvent(
                    mapOf(
                        "type" to EVENT_READY,
                        "mode" to activeConfig.mode.id,
                    ),
                )
            },
            mainExecutor,
        )
    }

    private fun analyzeImage(imageProxy: ImageProxy) {
        if (!isProcessingFrame.compareAndSet(false, true)) {
            imageProxy.close()
            return
        }

        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            isProcessingFrame.set(false)
            imageProxy.close()
            return
        }

        val inputImage = InputImage.fromMediaImage(
            mediaImage,
            imageProxy.imageInfo.rotationDegrees,
        )

        barcodeScanner.process(inputImage)
            .addOnSuccessListener(mainExecutor) { barcodes ->
                val rawValue = barcodes.firstNotNullOfOrNull { barcode ->
                    barcode.rawValue?.trim()?.takeIf(String::isNotEmpty)
                }
                if (rawValue != null) {
                    handleDetectedQrValue(rawValue)
                }
            }
            .addOnCompleteListener {
                isProcessingFrame.set(false)
                imageProxy.close()
            }
    }

    private fun handleDetectedQrValue(rawValue: String) {
        val activeConfig = sessionConfig ?: return

        when (activeConfig.mode) {
            VisionSessionMode.QR_REGISTRATION -> {
                emitIfDistinct(
                    rawValue = rawValue,
                    event = mapOf(
                        "type" to EVENT_QR_DETECTED,
                        "mode" to activeConfig.mode.id,
                        "rawValue" to rawValue,
                    ),
                )
            }

            VisionSessionMode.QR_MISSION -> {
                val matchesTarget = rawValue == activeConfig.expectedTargetValue
                updateActiveQrMissionState(QrMissionTrackingState.TRACKING)

                if (matchesTarget) {
                    completeActiveQrMission()
                    emitEvent(
                        mapOf(
                            "type" to EVENT_QR_MATCHED,
                            "mode" to activeConfig.mode.id,
                            "rawValue" to rawValue,
                        ),
                    )
                    stopSession()
                    AlarmRingingService.dismiss(appContext)
                    return
                }

                if (rawValue != lastMissionActivityValue) {
                    lastMissionActivityValue = rawValue
                    AlarmSessionCoordinator.extendMissionTimeout(appContext)
                }

                emitIfDistinct(
                    rawValue = rawValue,
                    event = mapOf(
                        "type" to EVENT_QR_MISMATCH,
                        "mode" to activeConfig.mode.id,
                        "rawValue" to rawValue,
                    ),
                )
            }
        }
    }

    private fun emitIfDistinct(rawValue: String, event: Map<String, Any?>) {
        val nowEpochMillis = System.currentTimeMillis()
        if (rawValue == lastEmittedValue &&
            nowEpochMillis - lastEmittedAtEpochMillis < DUPLICATE_EVENT_WINDOW_MS
        ) {
            return
        }

        lastEmittedValue = rawValue
        lastEmittedAtEpochMillis = nowEpochMillis
        emitEvent(event)
    }

    private fun emitError(code: String, message: String) {
        emitEvent(
            mapOf(
                "type" to EVENT_ERROR,
                "code" to code,
                "message" to message,
            ),
        )
    }

    private fun emitEvent(event: Map<String, Any?>) {
        mainExecutor.execute {
            eventSink?.success(event)
        }
    }

    private fun updateActiveQrMissionState(nextState: QrMissionTrackingState) {
        val activeSession = ringSessionStore.get()?.takeIf {
            it.isMissionActive && it.mission.spec.type == MissionSpec.TYPE_QR
        } ?: return

        val updatedMission = activeSession.mission.withQrTrackingState(nextState)
        if (updatedMission != activeSession.mission) {
            ringSessionStore.put(activeSession.withMission(updatedMission))
        }
    }

    private fun completeActiveQrMission() {
        val activeSession = ringSessionStore.get()?.takeIf {
            it.isMissionActive && it.mission.spec.type == MissionSpec.TYPE_QR
        } ?: return

        val updatedMission = activeSession.mission.completeQrMission()
        if (updatedMission != activeSession.mission) {
            ringSessionStore.put(activeSession.withMission(updatedMission))
        }
    }

    private fun resetSessionSignals() {
        lastMissionActivityValue = null
        lastEmittedValue = null
        lastEmittedAtEpochMillis = 0L
    }

    private fun unbindCamera() {
        cameraProvider?.unbindAll()
        cameraProvider = null
        boundConfig = null
    }

    private fun isCameraPermissionGranted(): Boolean {
        return ContextCompat.checkSelfPermission(
            appContext,
            Manifest.permission.CAMERA,
        ) == PackageManager.PERMISSION_GRANTED
    }

    companion object {
        private const val DUPLICATE_EVENT_WINDOW_MS = 1_000L
        const val EVENT_ERROR = "error"
        const val EVENT_QR_DETECTED = "qr_detected"
        const val EVENT_QR_MATCHED = "qr_matched"
        const val EVENT_QR_MISMATCH = "qr_mismatch"
        const val EVENT_READY = "ready"
    }
}

private data class VisionSessionConfig(
    val mode: VisionSessionMode,
    val expectedTargetValue: String? = null,
)

private enum class VisionSessionMode(val id: String) {
    QR_REGISTRATION("qr_registration"),
    QR_MISSION("qr_mission"),
}

