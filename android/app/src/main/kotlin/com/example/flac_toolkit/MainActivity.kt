package com.example.flac_toolkit

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteOrder
import kotlin.concurrent.thread

class MainActivity: FlutterActivity() {
    private val CHANNEL = "flac_toolkit/audio_decoder"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "extractPcmSamples") {
                val filePath = call.argument<String>("filePath")
                val statedBitDepth = call.argument<Int>("bitDepth") ?: 16
                if (filePath == null) {
                    result.error("INVALID_ARGS", "filePath is required", null)
                    return@setMethodCallHandler
                }
                thread(name = "FlacDecoderThread") {
                    try {
                        val data = decodeFlacSamples(filePath, statedBitDepth)
                        runOnUiThread {
                            result.success(data)
                        }
                    } catch (e: Exception) {
                        runOnUiThread {
                            result.error("DECODE_ERROR", e.localizedMessage, null)
                        }
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun decodeFlacSamples(filePath: String, statedBitDepth: Int): Map<String, Any> {
        val file = File(filePath)
        if (!file.exists()) {
            throw IllegalArgumentException("File not found: $filePath")
        }

        val extractor = MediaExtractor()
        // Use FileDescriptor to bypass Android 10+ Scoped Storage path restrictions
        java.io.FileInputStream(file).use { fis ->
            extractor.setDataSource(fis.fd)
        }

        var audioTrackIndex = -1
        var format: MediaFormat? = null
        for (i in 0 until extractor.trackCount) {
            val trackFormat = extractor.getTrackFormat(i)
            val mime = trackFormat.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("audio/")) {
                audioTrackIndex = i
                format = trackFormat
                break
            }
        }

        if (audioTrackIndex == -1 || format == null) {
            extractor.release()
            throw IllegalStateException("No audio track found in FLAC file")
        }

        extractor.selectTrack(audioTrackIndex)

        val mime = format.getString(MediaFormat.KEY_MIME) ?: "audio/flac"
        val sampleRate = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) format.getInteger(MediaFormat.KEY_SAMPLE_RATE) else 44100
        val channelCount = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) format.getInteger(MediaFormat.KEY_CHANNEL_COUNT) else 2
        val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) format.getLong(MediaFormat.KEY_DURATION) else 0L

        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(format, null, null, 0)
        codec.start()

        val targetSamplesPerWindow = 8192
        val sampledFloats = ArrayList<Float>()
        // 4 evenly spaced windows avoiding quiet intros/outros
        val seekPercentages = doubleArrayOf(0.20, 0.40, 0.60, 0.80)

        try {
            val bufferInfo = MediaCodec.BufferInfo()
            val TIMEOUT_US = 8000L

            for (pct in seekPercentages) {
                if (durationUs > 0) {
                    val targetUs = (durationUs * pct).toLong()
                    extractor.seekTo(targetUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                }

                codec.flush()
                var samplesCollected = 0
                var isEOS = false
                var loopCount = 0

                while (samplesCollected < targetSamplesPerWindow && !isEOS && loopCount < 160) {
                    loopCount++
                    val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (inIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inIndex)
                        if (inputBuffer != null) {
                            inputBuffer.clear()
                            val sampleSize = extractor.readSampleData(inputBuffer, 0)
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(inIndex, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                isEOS = true
                            } else {
                                val sampleTime = extractor.sampleTime
                                codec.queueInputBuffer(inIndex, 0, sampleSize, sampleTime, 0)
                                extractor.advance()
                            }
                        }
                    }

                    var outIndex = codec.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
                    while (outIndex >= 0) {
                        val outputBuffer = codec.getOutputBuffer(outIndex)
                        val outFormat = codec.outputFormat
                        val pcmEncoding = if (outFormat.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                            outFormat.getInteger(MediaFormat.KEY_PCM_ENCODING)
                        } else {
                            android.media.AudioFormat.ENCODING_PCM_16BIT
                        }

                        if (outputBuffer != null && bufferInfo.size > 0) {
                            outputBuffer.position(bufferInfo.offset)
                            outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                            outputBuffer.order(ByteOrder.LITTLE_ENDIAN)

                            when (pcmEncoding) {
                                android.media.AudioFormat.ENCODING_PCM_FLOAT -> {
                                    val floatBuf = outputBuffer.asFloatBuffer()
                                    while (floatBuf.hasRemaining() && samplesCollected < targetSamplesPerWindow) {
                                        val s = floatBuf.get()
                                        if (channelCount > 1) {
                                            for (ch in 1 until channelCount) {
                                                if (floatBuf.hasRemaining()) floatBuf.get()
                                            }
                                        }
                                        sampledFloats.add(s.coerceIn(-1.0f, 1.0f))
                                        samplesCollected++
                                    }
                                }
                                21 -> { // ENCODING_PCM_24BIT_PACKED (3 bytes per channel)
                                    val bytesPerFrame = 3 * channelCount
                                    while (outputBuffer.remaining() >= bytesPerFrame && samplesCollected < targetSamplesPerWindow) {
                                        val b0 = outputBuffer.get().toInt() and 0xFF
                                        val b1 = outputBuffer.get().toInt() and 0xFF
                                        val b2 = outputBuffer.get().toInt() // sign-extended high byte
                                        val s24 = (b2 shl 16) or (b1 shl 8) or b0
                                        val sFloat = (s24.toFloat() / 8388608.0f).coerceIn(-1.0f, 1.0f)
                                        sampledFloats.add(sFloat)
                                        samplesCollected++
                                        if (channelCount > 1) {
                                            outputBuffer.position(outputBuffer.position() + 3 * (channelCount - 1))
                                        }
                                    }
                                }
                                22 -> { // ENCODING_PCM_32BIT (4 bytes per channel)
                                    val intBuf = outputBuffer.asIntBuffer()
                                    while (intBuf.hasRemaining() && samplesCollected < targetSamplesPerWindow) {
                                        val s = intBuf.get()
                                        if (channelCount > 1) {
                                            for (ch in 1 until channelCount) {
                                                if (intBuf.hasRemaining()) intBuf.get()
                                            }
                                        }
                                        sampledFloats.add((s.toFloat() / 2147483648.0f).coerceIn(-1.0f, 1.0f))
                                        samplesCollected++
                                    }
                                }
                                else -> { // Default ENCODING_PCM_16BIT
                                    val shortBuf = outputBuffer.asShortBuffer()
                                    while (shortBuf.hasRemaining() && samplesCollected < targetSamplesPerWindow) {
                                        val s = shortBuf.get()
                                        if (channelCount > 1) {
                                            for (ch in 1 until channelCount) {
                                                if (shortBuf.hasRemaining()) shortBuf.get()
                                            }
                                        }
                                        sampledFloats.add(s.toFloat() / 32768.0f)
                                        samplesCollected++
                                    }
                                }
                            }
                        }
                        codec.releaseOutputBuffer(outIndex, false)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            isEOS = true
                            break
                        }
                        outIndex = codec.dequeueOutputBuffer(bufferInfo, 0L)
                    }
                }
            }
        } finally {
            try { codec.stop() } catch (_: Exception) {}
            try { codec.release() } catch (_: Exception) {}
            try { extractor.release() } catch (_: Exception) {}
        }

        // Shannon Entropy check for lowest 8 bits in 24-bit audio (Fake Hi-Res detection)
        var isFake24 = false
        if (statedBitDepth >= 24) {
            try {
                java.io.RandomAccessFile(file, "r").use { raf ->
                    if (raf.length() > 65536) {
                        raf.seek(raf.length() / 3)
                        val testBytes = ByteArray(32768)
                        val readLen = raf.read(testBytes)
                        if (readLen > 2000) {
                            val byteCounts = IntArray(256)
                            var total = 0
                            for (b in 0 until (readLen - 3) step 3) {
                                val lowByte = testBytes[b].toInt() and 0xFF
                                byteCounts[lowByte]++
                                total++
                            }
                            if (total > 200) {
                                var entropy = 0.0
                                for (count in byteCounts) {
                                    if (count > 0) {
                                        val p = count.toDouble() / total
                                        entropy -= p * (Math.log(p) / Math.log(2.0))
                                    }
                                }
                                val zeroRatio = byteCounts[0].toDouble() / total
                                if (zeroRatio > 0.95 || entropy < 1.0) {
                                    isFake24 = true
                                }
                            }
                        }
                    }
                }
            } catch (_: Exception) {}
        }

        val floatList = DoubleArray(sampledFloats.size)
        for (i in sampledFloats.indices) {
            floatList[i] = sampledFloats[i].toDouble()
        }

        return mapOf(
            "sampleRate" to sampleRate,
            "channels" to channelCount,
            "samples" to floatList,
            "isPaddedFake24" to isFake24
        )
    }
}
