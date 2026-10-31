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
        extractor.setDataSource(filePath)

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
        val seekPercentages = doubleArrayOf(0.25, 0.50, 0.75)

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

                while (samplesCollected < targetSamplesPerWindow && !isEOS && loopCount < 150) {
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
                        if (outputBuffer != null && bufferInfo.size > 0) {
                            outputBuffer.position(bufferInfo.offset)
                            outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                            outputBuffer.order(ByteOrder.LITTLE_ENDIAN)

                            val shortBuf = outputBuffer.asShortBuffer()
                            while (shortBuf.hasRemaining() && samplesCollected < targetSamplesPerWindow) {
                                var monoVal = 0.0f
                                for (ch in 0 until channelCount) {
                                    if (shortBuf.hasRemaining()) {
                                        val s = shortBuf.get()
                                        if (ch == 0) {
                                            monoVal = s.toFloat() / 32768.0f
                                        }
                                    }
                                }
                                sampledFloats.add(monoVal)
                                samplesCollected++
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

        // Check for fake 24-bit (zero padded lower 8 bits)
        var isFake24 = false
        if (statedBitDepth >= 24) {
            // Read 20KB from middle of file to check byte distribution
            try {
                java.io.RandomAccessFile(file, "r").use { raf ->
                    if (raf.length() > 40960) {
                        raf.seek(raf.length() / 2)
                        val testBytes = ByteArray(16384)
                        val readLen = raf.read(testBytes)
                        if (readLen > 1000) {
                            var zeroCount = 0
                            var totalCheck = 0
                            for (b in 0 until (readLen - 3) step 3) {
                                val lowByte = testBytes[b].toInt() and 0xFF
                                if (lowByte == 0) zeroCount++
                                totalCheck++
                            }
                            if (totalCheck > 100 && (zeroCount.toDouble() / totalCheck) > 0.96) {
                                isFake24 = true
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
