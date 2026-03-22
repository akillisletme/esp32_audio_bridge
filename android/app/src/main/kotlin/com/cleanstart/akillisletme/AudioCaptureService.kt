package com.cleanstart.akillisletme

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat

/**
 * Sistem sesini yakalayan Foreground Service.
 *
 * Android 10 (API 29) ve üzeri gerektirir.
 *
 * [AudioPlaybackCaptureConfiguration] ile medya/oyun/unknown seslerini yakalar.
 * Her [bufferSize] byte okuyunca [MainActivity.eventSink] üzerinden
 * Flutter'a ByteArray gönderir.
 *
 * Kullanım:
 * 1. [projectionResultCode] ve [projectionData] ayarla
 * 2. Servisi başlat + bağla
 * 3. [startCapture] çağır → ses akışı başlar
 * 4. [stopCapture] çağır → kaynaklar serbest bırakılır
 */
class AudioCaptureService : Service() {

    companion object {
        /** MainActivity'den set edilir — MediaProjection token. */
        var projectionResultCode: Int = -1
        var projectionData: Intent? = null

        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID     = "audio_capture_ch"

        /**
         * AudioRecord iç buffer'ı en az şu çarpan kadar büyük tutulur.
         * Küçük [bufferSize]'da overflow riskini azaltır.
         */
        private const val INTERNAL_BUFFER_MULTIPLIER = 4
    }

    inner class LocalBinder : Binder() {
        fun getService(): AudioCaptureService = this@AudioCaptureService
    }

    private val binder      = LocalBinder()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var mediaProjection: MediaProjection? = null
    private var audioRecord:     AudioRecord?     = null
    private var captureThread:   Thread?          = null

    @Volatile
    private var isCapturing = false

    override fun onBind(intent: Intent): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    /**
     * Ses yakalamayı başlatır.
     *
     * @param config Flutter'dan gelen Map:
     *   - "sampleRate": Int  (örnek: 44100)
     *   - "channels":   Int  (1=mono, 2=stereo)
     *   - "bufferSize": Int  (byte cinsinden paket boyutu)
     */
    @RequiresApi(Build.VERSION_CODES.Q)
    fun startCapture(config: Map<String, Any>) {
        val sampleRate = (config["sampleRate"] as? Int) ?: 44100
        val channels   = (config["channels"]   as? Int) ?: 1
        val bufferSize = (config["bufferSize"] as? Int) ?: 1024

        // MediaProjection oluştur
        val projManager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val data = projectionData ?: run {
            mainHandler.post {
                MainActivity.eventSink?.error("NO_PROJECTION", "Projection verisi yok", null)
            }
            return
        }
        mediaProjection = projManager.getMediaProjection(projectionResultCode, data)

        // AudioFormat
        val channelMask = if (channels == 1)
            AudioFormat.CHANNEL_IN_MONO
        else
            AudioFormat.CHANNEL_IN_STEREO

        // AudioPlaybackCaptureConfiguration — sistem seslerini yakala
        val captureConfig = AudioPlaybackCaptureConfiguration
            .Builder(mediaProjection!!)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)   // müzik, video
            .addMatchingUsage(AudioAttributes.USAGE_GAME)    // oyun sesi
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN) // diğer
            .build()

        val audioFormat = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setSampleRate(sampleRate)
            .setChannelMask(channelMask)
            .build()

        // Minimum buffer; overflow önlemek için daha büyük iç buffer kullan
        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate,
            channelMask,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val internalBuf = maxOf(
            bufferSize * INTERNAL_BUFFER_MULTIPLIER,
            minBuf * 2,
        )

        audioRecord = AudioRecord.Builder()
            .setAudioPlaybackCaptureConfig(captureConfig)
            .setAudioFormat(audioFormat)
            .setBufferSizeInBytes(internalBuf)
            .build()

        isCapturing = true
        audioRecord?.startRecording()

        // Ses okuma döngüsü — ayrı thread
        captureThread = Thread {
            val buf = ByteArray(bufferSize)
            while (isCapturing) {
                val read = audioRecord?.read(
                    buf, 0, bufferSize, AudioRecord.READ_BLOCKING,
                ) ?: -1

                when {
                    read > 0 -> {
                        // Defensive copy — thread safe
                        val chunk = buf.copyOf(read)
                        mainHandler.post {
                            MainActivity.eventSink?.success(chunk)
                        }
                    }
                    read < 0 -> {
                        mainHandler.post {
                            MainActivity.eventSink?.error(
                                "READ_ERROR",
                                "AudioRecord read hatası: $read",
                                null,
                            )
                        }
                        break
                    }
                    // read == 0 → buffer boş, döngü devam eder
                }
            }
        }.also {
            it.isDaemon = true
            it.name = "AudioCaptureThread"
            it.start()
        }
    }

    /** Yakalamayı durdurur ve tüm kaynakları serbest bırakır. */
    fun stopCapture() {
        isCapturing = false
        captureThread?.join(2_000L) // en fazla 2 sn bekle
        captureThread = null

        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null

        mediaProjection?.stop()
        mediaProjection = null
    }

    override fun onDestroy() {
        stopCapture()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Ses Yakalama",
                NotificationManager.IMPORTANCE_LOW,
            )
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ses Akışı Aktif")
            .setContentText("Sistem sesi ESP32'ye aktarılıyor")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
}
