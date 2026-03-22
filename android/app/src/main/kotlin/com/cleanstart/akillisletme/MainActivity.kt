package com.cleanstart.akillisletme

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter ana Activity.
 *
 * Platform channel'ları:
 * - [METHOD_CHANNEL]: startCapture / stopCapture
 * - [EVENT_CHANNEL]: PCM16 ses chunk'ları → Flutter
 *
 * Akış:
 * 1. Flutter → startCapture(config)
 * 2. Sistem MediaProjection izin dialogu gösterilir
 * 3. İzin onaylanırsa [AudioCaptureService] başlatılır ve bağlanılır
 * 4. Servis ses okur → [eventSink] → Flutter EventChannel
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "com.cleanstart.akillisletme/audio_capture"
        const val EVENT_CHANNEL  = "com.cleanstart.akillisletme/audio_stream"

        private const val PROJECTION_REQUEST_CODE = 1001

        /** Servis bu sink'e yazarak Flutter'a ses gönderir. */
        @JvmStatic
        var eventSink: EventChannel.EventSink? = null
    }

    private var captureService: AudioCaptureService? = null
    private var isBound = false
    private var pendingConfig: Map<String, Any>? = null

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            captureService = (binder as AudioCaptureService.LocalBinder).getService()
            isBound = true
            pendingConfig?.let { cfg ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    captureService?.startCapture(cfg)
                } else {
                    eventSink?.error("API_TOO_LOW", "Android 10+ gerekli", null)
                }
                pendingConfig = null
            }
        }

        override fun onServiceDisconnected(name: ComponentName) {
            captureService = null
            isBound = false
        }
    }

    private val projectionManager: MediaProjectionManager by lazy {
        getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
            }
            override fun onCancel(args: Any?) {
                eventSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startCapture" -> {
                    @Suppress("UNCHECKED_CAST")
                    val config = call.arguments as? Map<String, Any> ?: emptyMap()
                    requestMediaProjection(config)
                    result.success(null)
                }
                "stopCapture" -> {
                    doStopCapture()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestMediaProjection(config: Map<String, Any>) {
        pendingConfig = config
        @Suppress("DEPRECATION")
        startActivityForResult(
            projectionManager.createScreenCaptureIntent(),
            PROJECTION_REQUEST_CODE,
        )
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PROJECTION_REQUEST_CODE) return

        if (resultCode == Activity.RESULT_OK && data != null) {
            AudioCaptureService.projectionResultCode = resultCode
            AudioCaptureService.projectionData = data
            val intent = Intent(this, AudioCaptureService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
        } else {
            pendingConfig = null
            eventSink?.error("PERMISSION_DENIED", "MediaProjection izni reddedildi", null)
        }
    }

    private fun doStopCapture() {
        captureService?.stopCapture()
        if (isBound) {
            unbindService(serviceConnection)
            isBound = false
        }
        stopService(Intent(this, AudioCaptureService::class.java))
        captureService = null
    }

    override fun onDestroy() {
        if (isBound) {
            unbindService(serviceConnection)
            isBound = false
        }
        super.onDestroy()
    }
}
