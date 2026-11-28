package com.example.flac_toolkit

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.clashplayer.dsp.Resampler
import com.clashplayer.service.NativeAudioOutput
import com.clashplayer.usb.UsbAudioOutput
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicLong
import kotlin.concurrent.thread

/**
 * AcoustiQ Native Audio Engine Bridge
 *
 * Implements:
 * 1. Multi-depth MediaCodec PCM decoding (16-bit, 24-bit packed, 32-bit, Float32).
 * 2. Direct USB Audio Class 1/2 isochronous output (UsbAudioOutput / usbiso.c) with runtime permission handling.
 * 3. Low-latency native float PCM fallback output via AAudio (Android 28+) or OpenSL ES.
 * 4. Honest signal-path telemetry (isBitPerfect == true strictly when exact USB DAC clock/bit-depth lock is active).
 */
class NativeAudioEngine(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "acoustiq/clash_native_audio"
        private const val TAG = "NativeAudioEngine"
    }

    private val usbPermissionAction = "${context.packageName}.USB_PERMISSION"
    private val sessionCounter = AtomicLong(0L)

    private var nativeOutput: NativeAudioOutput? = null
    private var usbOutput: UsbAudioOutput? = null
    private var playbackThread: Thread? = null
    private var receiverRegistered = false

    @Volatile private var usbPermissionPending = false
    @Volatile private var isPlaying = false
    @Volatile private var isPaused = false
    @Volatile private var playbackCompleted = false
    @Volatile private var seekRequestedMs = -1L
    @Volatile private var currentPositionMs = 0L
    @Volatile private var totalDurationMs = 0L
    @Volatile private var currentFilePath: String? = null
    @Volatile private var activeDriverName = "AAudio"
    @Volatile private var activeEndpointName = "Internal Audio Hardware"
    @Volatile private var currentSampleRate = 48000
    @Volatile private var currentBitDepth = 16
    @Volatile private var currentChannels = 2
    @Volatile private var isBitPerfect = false

    private val mainHandler = Handler(Looper.getMainLooper())

    private val usbPermissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent?.action == usbPermissionAction) {
                usbPermissionPending = false
                val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                Log.i(TAG, "USB DAC permission result: granted=$granted")
            }
        }
    }

    private fun ensureUsbReceiverRegistered() {
        if (receiverRegistered) return
        try {
            val filter = IntentFilter(usbPermissionAction)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(usbPermissionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                context.registerReceiver(usbPermissionReceiver, filter)
            }
            receiverRegistered = true
        } catch (e: Exception) {
            Log.w(TAG, "Could not register USB receiver: ${e.message}")
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAudioEngineStatus" -> {
                result.success(getEngineStatus())
            }
            "startNativePlayback" -> {
                val filePath = call.argument<String>("filePath")
                val preferUsb = call.argument<Boolean>("preferUsb") ?: true
                if (filePath == null || !File(filePath).exists()) {
                    result.error("FILE_NOT_FOUND", "File not found: $filePath", null)
                    return
                }
                startPlayback(filePath, preferUsb, result)
            }
            "pauseNativePlayback" -> {
                pausePlayback()
                result.success(true)
            }
            "resumeNativePlayback" -> {
                resumePlayback()
                result.success(true)
            }
            "stopNativePlayback" -> {
                stopPlayback()
                result.success(true)
            }
            "seekNativePlayback" -> {
                val positionMs = (call.argument<Number>("positionMs"))?.toLong() ?: 0L
                seekRequestedMs = positionMs
                result.success(true)
            }
            "getPlaybackPosition" -> {
                result.success(mapOf(
                    "positionMs" to currentPositionMs,
                    "durationMs" to totalDurationMs,
                    "isPlaying" to isPlaying,
                    "isPaused" to isPaused,
                    "completed" to playbackCompleted,
                    "driver" to activeDriverName,
                    "endpoint" to activeEndpointName,
                    "bitPerfect" to isBitPerfect,
                    "sampleRate" to currentSampleRate,
                    "bitDepth" to currentBitDepth,
                    "channels" to currentChannels
                ))
            }
            else -> result.notImplemented()
        }
    }

    private fun findUsbAudioDevice(usbManager: UsbManager?): UsbDevice? {
        if (usbManager == null) return null
        val devices = usbManager.deviceList.values
        devices.firstOrNull(UsbAudioOutput::isUsbAudio)?.let { return it }
        for (device in devices) {
            for (i in 0 until device.interfaceCount) {
                if (device.getInterface(i).interfaceClass == UsbConstants.USB_CLASS_AUDIO) {
                    return device
                }
            }
        }
        return null
    }

    private fun requestUsbPermissionIfNeeded(usbManager: UsbManager, device: UsbDevice) {
        if (usbPermissionPending || usbManager.hasPermission(device)) return
        ensureUsbReceiverRegistered()
        usbPermissionPending = true
        try {
            val intent = Intent(usbPermissionAction).setPackage(context.packageName)
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)
            usbManager.requestPermission(device, pendingIntent)
        } catch (e: Exception) {
            usbPermissionPending = false
            Log.w(TAG, "USB permission request failed: ${e.message}")
        }
    }

    private fun getEngineStatus(): Map<String, Any?> {
        val usbManager = context.getSystemService(Context.USB_SERVICE) as? UsbManager
        val usbDevice = findUsbAudioDevice(usbManager)
        val hasUsbDac = usbDevice != null
        val attachedDacName = usbDevice?.let { it.productName ?: it.deviceName }

        return mapOf(
            "hasUsbDac" to hasUsbDac,
            "usbDacName" to (attachedDacName ?: "No USB DAC detected"),
            "defaultDriver" to if (hasUsbDac) "USB Direct (UAC)" else "AAudio",
            "activeDriver" to activeDriverName,
            "endpoint" to activeEndpointName,
            "isBitPerfect" to isBitPerfect,
            "sampleRate" to currentSampleRate,
            "bitDepth" to currentBitDepth
        )
    }

    @Synchronized
    private fun startPlayback(filePath: String, preferUsb: Boolean, result: MethodChannel.Result) {
        stopPlayback()
        val mySession = sessionCounter.incrementAndGet()

        currentFilePath = filePath
        currentPositionMs = 0L
        totalDurationMs = 0L
        playbackCompleted = false
        isPlaying = true
        isPaused = false
        seekRequestedMs = -1L

        playbackThread = thread(name = "AcoustiQAudioThread") {
            try {
                decodeAndStream(mySession, filePath, preferUsb, result)
            } catch (e: Exception) {
                Log.e(TAG, "Playback error: ${e.message}", e)
                if (sessionCounter.get() == mySession) {
                    isPlaying = false
                    isPaused = false
                    isBitPerfect = false
                }
                mainHandler.post {
                    try {
                        result.error("PLAYBACK_ERROR", e.localizedMessage, null)
                    } catch (_: Exception) {}
                }
            }
        }
    }

    private fun resolveSourceBitDepth(format: MediaFormat): Int {
        if (format.containsKey("bits-per-sample")) {
            return format.getInteger("bits-per-sample").coerceIn(8, 32)
        }
        if (format.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
            return when (format.getInteger(MediaFormat.KEY_PCM_ENCODING)) {
                AudioFormat.ENCODING_PCM_24BIT_PACKED -> 24
                AudioFormat.ENCODING_PCM_32BIT, AudioFormat.ENCODING_PCM_FLOAT -> 32
                else -> 16
            }
        }
        return 16
    }

    private fun decodeBufferToFloats(buf: ByteBuffer, encoding: Int, byteSize: Int): FloatArray {
        return when (encoding) {
            AudioFormat.ENCODING_PCM_FLOAT -> {
                val count = byteSize / 4
                FloatArray(count) {
                    val f = buf.float
                    if (f.isNaN() || f.isInfinite()) 0f else f
                }
            }
            AudioFormat.ENCODING_PCM_32BIT -> {
                val count = byteSize / 4
                FloatArray(count) { buf.int / 2147483648.0f }
            }
            AudioFormat.ENCODING_PCM_24BIT_PACKED -> {
                val count = byteSize / 3
                FloatArray(count) {
                    val b0 = buf.get().toInt() and 0xFF
                    val b1 = buf.get().toInt() and 0xFF
                    val b2 = buf.get().toInt()
                    val v = (b2 shl 16) or (b1 shl 8) or b0
                    v / 8388608.0f
                }
            }
            else -> {
                val count = byteSize / 2
                FloatArray(count) { buf.short / 32768.0f }
            }
        }
    }

    private fun decodeAndStream(mySession: Long, filePath: String, preferUsb: Boolean, result: MethodChannel.Result) {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(filePath)
        } catch (e: Exception) {
            mainHandler.post { result.error("DATA_SOURCE_ERROR", e.message, null) }
            return
        }

        var trackIndex = -1
        var format: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val f = extractor.getTrackFormat(i)
            val mime = f.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("audio/")) {
                trackIndex = i
                format = f
                break
            }
        }

        if (trackIndex == -1 || format == null) {
            extractor.release()
            mainHandler.post { result.error("NO_AUDIO_TRACK", "No audio track in file", null) }
            return
        }

        extractor.selectTrack(trackIndex)
        val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
        val sampleRate = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) format.getInteger(MediaFormat.KEY_SAMPLE_RATE) else 44100
        val channels = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) format.getInteger(MediaFormat.KEY_CHANNEL_COUNT) else 2
        val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) format.getLong(MediaFormat.KEY_DURATION) else 0L
        val bitDepth = resolveSourceBitDepth(format)

        currentSampleRate = sampleRate
        currentBitDepth = bitDepth
        currentChannels = channels
        totalDurationMs = durationUs / 1000

        // 1. Prefer USB Audio Class DAC direct output if attached & permitted
        var openedUsb: UsbAudioOutput? = null
        var openedNative: NativeAudioOutput? = null
        var activeResampler: Resampler? = null

        val usbManager = context.getSystemService(Context.USB_SERVICE) as? UsbManager
        val usbDevice = if (preferUsb) findUsbAudioDevice(usbManager) else null
        if (preferUsb && usbManager != null && usbDevice != null) {
            if (!usbManager.hasPermission(usbDevice)) {
                requestUsbPermissionIfNeeded(usbManager, usbDevice)
            } else if (UsbAudioOutput.isUsbAudio(usbDevice)) {
                try {
                    val candidate = UsbAudioOutput.open(
                        manager = usbManager,
                        device = usbDevice,
                        sampleRate = sampleRate,
                        bitDepth = bitDepth,
                        channels = channels,
                        allowResample = true
                    )
                    if (channels <= candidate.channels) {
                        openedUsb = candidate
                        if (candidate.sampleRate != sampleRate) {
                            activeResampler = Resampler(sampleRate, candidate.sampleRate, channels)
                        }
                        usbOutput = candidate
                        activeDriverName = "USB Direct (${candidate.classLabel})"
                        activeEndpointName = "${usbDevice.productName ?: "USB DAC"} • ${candidate.description}"
                        isBitPerfect = candidate.exact && activeResampler == null
                        currentSampleRate = candidate.sampleRate
                    } else {
                        candidate.close()
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "USB DAC direct open failed, falling back to AAudio: ${e.message}")
                }
            }
        }

        // 2. Fallback to AAudio / OpenSL ES float output (never bit-perfect due to AudioFlinger mixer)
        if (openedUsb == null) {
            openedNative = NativeAudioOutput.open(NativeAudioOutput.AAUDIO, sampleRate, channels)
                ?: NativeAudioOutput.open(NativeAudioOutput.OPENSL, sampleRate, channels)

            if (openedNative == null) {
                extractor.release()
                if (sessionCounter.get() == mySession) {
                    isPlaying = false
                    isBitPerfect = false
                }
                mainHandler.post { result.error("OUTPUT_INIT_FAILED", "Could not open native audio output", null) }
                return
            }

            nativeOutput = openedNative
            activeDriverName = openedNative.label
            activeEndpointName = "Internal Audio Hardware (Shared Mixer)"
            isBitPerfect = false
            openedNative.start()
        }

        val reportedDriver = activeDriverName
        val reportedEndpoint = activeEndpointName
        val reportedBitPerfect = isBitPerfect

        mainHandler.post {
            result.success(mapOf(
                "durationMs" to totalDurationMs,
                "sampleRate" to currentSampleRate,
                "bitDepth" to currentBitDepth,
                "channels" to currentChannels,
                "driver" to reportedDriver,
                "endpoint" to reportedEndpoint,
                "bitPerfect" to reportedBitPerfect
            ))
        }

        // 3. Configure MediaCodec Decoder
        val codec = MediaCodec.createDecoderByType(mime)
        var outEncoding = if (format.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
            format.getInteger(MediaFormat.KEY_PCM_ENCODING)
        } else {
            AudioFormat.ENCODING_PCM_16BIT
        }
        var resampleScratch = FloatArray(0)
        var sawInputEOS = false
        var sawOutputEOS = false

        try {
            codec.configure(format, null, null, 0)
            codec.start()

            val info = MediaCodec.BufferInfo()
            val timeoutUs = 10000L

            while (isPlaying && !sawOutputEOS && sessionCounter.get() == mySession) {
                if (isPaused) {
                    openedNative?.pause()
                    openedUsb?.flush()
                    while (isPaused && isPlaying && sessionCounter.get() == mySession) {
                        Thread.sleep(20)
                    }
                    if (isPlaying && sessionCounter.get() == mySession) {
                        openedNative?.start()
                    }
                }

                // Handle Seek
                val seekTarget = seekRequestedMs
                if (seekTarget >= 0) {
                    seekRequestedMs = -1L
                    codec.flush()
                    openedNative?.flush()
                    openedUsb?.flush()
                    activeResampler?.reset()
                    extractor.seekTo(seekTarget * 1000, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                    currentPositionMs = seekTarget
                }

                // Feed Input
                if (!sawInputEOS) {
                    val inputIndex = codec.dequeueInputBuffer(timeoutUs)
                    if (inputIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inputIndex)
                        if (inputBuffer != null) {
                            val sampleSize = extractor.readSampleData(inputBuffer, 0)
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                sawInputEOS = true
                            } else {
                                val presentationTimeUs = extractor.sampleTime
                                codec.queueInputBuffer(inputIndex, 0, sampleSize, presentationTimeUs, 0)
                                extractor.advance()
                            }
                        }
                    }
                }

                // Drain Output
                val outputIndex = codec.dequeueOutputBuffer(info, timeoutUs)
                if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val outFmt = codec.outputFormat
                    if (outFmt.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                        outEncoding = outFmt.getInteger(MediaFormat.KEY_PCM_ENCODING)
                    }
                } else if (outputIndex >= 0) {
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        sawOutputEOS = true
                    }

                    val outputBuffer = codec.getOutputBuffer(outputIndex)
                    if (outputBuffer != null && info.size > 0 && isPlaying && sessionCounter.get() == mySession) {
                        currentPositionMs = info.presentationTimeUs / 1000

                        outputBuffer.position(info.offset)
                        outputBuffer.limit(info.offset + info.size)
                        outputBuffer.order(ByteOrder.LITTLE_ENDIAN)

                        val floatBuf = decodeBufferToFloats(outputBuffer, outEncoding, info.size)

                        try {
                            if (openedUsb != null) {
                                val r = activeResampler
                                if (r != null) {
                                    val maxOut = r.maxOutFrames(floatBuf.size / channels) * channels
                                    if (resampleScratch.size < maxOut) resampleScratch = FloatArray(maxOut)
                                    val written = r.process(floatBuf, floatBuf.size, resampleScratch)
                                    if (written > 0) {
                                        openedUsb.write(resampleScratch, written, channels)
                                    }
                                } else {
                                    openedUsb.write(floatBuf, floatBuf.size, channels)
                                }
                            } else {
                                openedNative?.write(floatBuf, floatBuf.size)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Native write error: ${e.message}")
                            break
                        }
                    }
                    codec.releaseOutputBuffer(outputIndex, false)
                }
            }
        } finally {
            try { codec.stop() } catch (_: Exception) {}
            try { codec.release() } catch (_: Exception) {}
            try { extractor.release() } catch (_: Exception) {}
            try { openedUsb?.close() } catch (_: Exception) {}
            try { openedNative?.close() } catch (_: Exception) {}

            if (sessionCounter.get() == mySession) {
                playbackCompleted = sawOutputEOS && isPlaying
                isPlaying = false
                isPaused = false
                usbOutput = null
                nativeOutput = null
            }
        }
    }

    @Synchronized
    private fun pausePlayback() {
        isPaused = true
        nativeOutput?.pause()
    }

    @Synchronized
    private fun resumePlayback() {
        isPaused = false
        nativeOutput?.start()
    }

    @Synchronized
    private fun stopPlayback() {
        sessionCounter.incrementAndGet()
        isPlaying = false
        isPaused = false
        playbackCompleted = false
        try { usbOutput?.close() } catch (_: Exception) {}
        try { nativeOutput?.close() } catch (_: Exception) {}
        usbOutput = null
        nativeOutput = null
        playbackThread?.interrupt()
        try { playbackThread?.join(300) } catch (_: Exception) {}
        playbackThread = null
    }
}
