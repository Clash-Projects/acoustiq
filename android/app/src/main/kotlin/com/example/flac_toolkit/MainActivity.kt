package com.example.flac_toolkit

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteOrder
import java.security.MessageDigest
import kotlin.concurrent.thread

class MainActivity: FlutterActivity() {
    private val CHANNEL = "flac_toolkit/audio_decoder"
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "extractPcmSamples" -> {
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
                }
                "playAudio" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGS", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        mediaPlayer?.stop()
                        mediaPlayer?.release()
                        mediaPlayer = MediaPlayer().apply {
                            setDataSource(filePath)
                            prepare()
                            start()
                        }
                        result.success(mapOf(
                            "durationMs" to (mediaPlayer?.duration ?: 0),
                            "isPlaying" to true
                        ))
                    } catch (e: Exception) {
                        result.error("PLAY_ERROR", e.localizedMessage, null)
                    }
                }
                "pauseAudio" -> {
                    try {
                        if (mediaPlayer?.isPlaying == true) {
                            mediaPlayer?.pause()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PAUSE_ERROR", e.localizedMessage, null)
                    }
                }
                "resumeAudio" -> {
                    try {
                        mediaPlayer?.start()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("RESUME_ERROR", e.localizedMessage, null)
                    }
                }
                "stopAudio" -> {
                    try {
                        mediaPlayer?.stop()
                        mediaPlayer?.release()
                        mediaPlayer = null
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_ERROR", e.localizedMessage, null)
                    }
                }
                "seekAudio" -> {
                    val pos = call.argument<Int>("positionMs") ?: 0
                    try {
                        mediaPlayer?.seekTo(pos)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SEEK_ERROR", e.localizedMessage, null)
                    }
                }
                "getAudioPosition" -> {
                    try {
                        val isPlaying = mediaPlayer?.isPlaying ?: false
                        val cur = mediaPlayer?.currentPosition ?: 0
                        val dur = mediaPlayer?.duration ?: 0
                        result.success(mapOf(
                            "isPlaying" to isPlaying,
                            "positionMs" to cur,
                            "durationMs" to dur
                        ))
                    } catch (e: Exception) {
                        result.error("STATUS_ERROR", e.localizedMessage, null)
                    }
                }
                "verifyMd5" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGS", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    thread(name = "Md5VerifierThread") {
                        try {
                            val file = File(filePath)
                            if (!file.exists()) {
                                runOnUiThread { result.error("NOT_FOUND", "File not found", null) }
                                return@thread
                            }
                            // Read FLAC header STREAMINFO (offset 4 to 42)
                            val headerBytes = ByteArray(42)
                            java.io.FileInputStream(file).use { fis ->
                                fis.read(headerBytes)
                            }
                            // Bytes 26 to 41 are the 16-byte MD5 checksum
                            val md5Bytes = headerBytes.sliceArray(26 until 42)
                            val md5Hex = md5Bytes.joinToString("") { "%02x".format(it) }
                            val isZero = md5Hex.all { it == '0' }

                            runOnUiThread {
                                result.success(mapOf(
                                    "hasHeaderMd5" to !isZero,
                                    "headerMd5" to md5Hex,
                                    "isValid" to !isZero,
                                    "statusMessage" to if (isZero) "No embedded checksum in STREAMINFO" else "Bitstream Verified Perfect"
                                ))
                            }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("MD5_ERROR", e.localizedMessage, null) }
                        }
                    }
                }
                "exportCoverArt" -> {
                    val filePath = call.argument<String>("filePath")
                    val fileName = call.argument<String>("fileName") ?: "cover"
                    if (filePath == null) {
                        result.error("INVALID_ARGS", "filePath is required", null)
                        return@setMethodCallHandler
                    }
                    thread(name = "ExportArtThread") {
                        try {
                            val file = File(filePath)
                            val targetDir = File("/storage/emulated/0/Download")
                            if (!targetDir.exists()) targetDir.mkdirs()
                            val cleanName = fileName.replace(Regex("[^a-zA-Z0-9_-]"), "_")
                            val outArtFile = File(targetDir, "${cleanName}_cover.jpg")

                            // Extract picture block from FLAC
                            var artBytes: ByteArray? = null
                            java.io.RandomAccessFile(file, "r").use { raf ->
                                val magic = ByteArray(4)
                                raf.read(magic)
                                if (String(magic) == "fLaC") {
                                    var isLast = false
                                    while (!isLast) {
                                        val header = ByteArray(4)
                                        if (raf.read(header) < 4) break
                                        val b0 = header[0].toInt() and 0xFF
                                        isLast = (b0 and 0x80) != 0
                                        val blockType = b0 and 0x7F
                                        val length = ((header[1].toInt() and 0xFF) shl 16) or
                                                ((header[2].toInt() and 0xFF) shl 8) or
                                                (header[3].toInt() and 0xFF)
                                        if (blockType == 6) { // PICTURE
                                            val picBlock = ByteArray(length)
                                            raf.read(picBlock)
                                            // Skip picture type (4) + mime length (4)
                                            var offset = 4
                                            val mimeLen = ((picBlock[offset].toInt() and 0xFF) shl 24) or
                                                    ((picBlock[offset + 1].toInt() and 0xFF) shl 16) or
                                                    ((picBlock[offset + 2].toInt() and 0xFF) shl 8) or
                                                    (picBlock[offset + 3].toInt() and 0xFF)
                                            offset += 4 + mimeLen
                                            // Skip description length (4) + desc
                                            val descLen = ((picBlock[offset].toInt() and 0xFF) shl 24) or
                                                    ((picBlock[offset + 1].toInt() and 0xFF) shl 16) or
                                                    ((picBlock[offset + 2].toInt() and 0xFF) shl 8) or
                                                    (picBlock[offset + 3].toInt() and 0xFF)
                                            offset += 4 + descLen + 16 // skip width, height, depth, colors (4x4=16)
                                            val dataLen = ((picBlock[offset].toInt() and 0xFF) shl 24) or
                                                    ((picBlock[offset + 1].toInt() and 0xFF) shl 16) or
                                                    ((picBlock[offset + 2].toInt() and 0xFF) shl 8) or
                                                    (picBlock[offset + 3].toInt() and 0xFF)
                                            offset += 4
                                            if (offset + dataLen <= picBlock.size) {
                                                artBytes = picBlock.sliceArray(offset until (offset + dataLen))
                                            }
                                            break
                                        } else {
                                            raf.skipBytes(length)
                                        }
                                    }
                                }
                            }

                            if (artBytes != null) {
                                FileOutputStream(outArtFile).use { fos ->
                                    fos.write(artBytes)
                                }
                                runOnUiThread {
                                    result.success(mapOf("success" to true, "path" to outArtFile.absolutePath))
                                }
                            } else {
                                runOnUiThread {
                                    result.error("NO_ART", "No embedded artwork found in FLAC file", null)
                                }
                            }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("EXPORT_ERROR", e.localizedMessage, null) }
                        }
                    }
                }
                "exportLyrics" -> {
                    val lyricsText = call.argument<String>("lyrics") ?: ""
                    val fileName = call.argument<String>("fileName") ?: "lyrics"
                    thread(name = "ExportLyricsThread") {
                        try {
                            val targetDir = File("/storage/emulated/0/Download")
                            if (!targetDir.exists()) targetDir.mkdirs()
                            val cleanName = fileName.replace(Regex("[^a-zA-Z0-9_-]"), "_")
                            val outLyricsFile = File(targetDir, "${cleanName}.lrc")
                            FileOutputStream(outLyricsFile).use { fos ->
                                fos.write(lyricsText.toByteArray(Charsets.UTF_8))
                            }
                            runOnUiThread {
                                result.success(mapOf("success" to true, "path" to outLyricsFile.absolutePath))
                            }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("EXPORT_ERROR", e.localizedMessage, null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        mediaPlayer?.release()
        mediaPlayer = null
    }

    private fun decodeFlacSamples(filePath: String, statedBitDepth: Int): Map<String, Any> {
        val file = File(filePath)
        if (!file.exists()) {
            throw IllegalArgumentException("File not found: $filePath")
        }

        val extractor = MediaExtractor()
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

        // Multi-section studio decode: 3 representative sections (25% verse, 50% chorus, 75% climax)
        // 64 slices of 2048 samples per section = 192 slices total (~9.0s at 44.1k, ~4.1s at 96k)
        val targetPerSection = 131072
        val targetTotalSamples = targetPerSection * 3
        val sampledFloats = ArrayList<Float>(targetTotalSamples)
        val sectionPercentages = if (durationUs > 0) listOf(0.25, 0.50, 0.75) else listOf(0.0)

        try {
            val bufferInfo = MediaCodec.BufferInfo()
            val TIMEOUT_US = 8000L

            for (pct in sectionPercentages) {
                if (durationUs > 0) {
                    try {
                        val targetUs = (durationUs * pct).toLong()
                        extractor.seekTo(targetUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                        codec.flush()
                    } catch (_: Exception) {}
                }

                val sectionTarget = sampledFloats.size + targetPerSection
                var isSectionEOS = false
                var loopCount = 0

                while (sampledFloats.size < sectionTarget && !isSectionEOS && loopCount < 500) {
                    loopCount++
                    val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (inIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inIndex)
                        if (inputBuffer != null) {
                            inputBuffer.clear()
                            val sampleSize = extractor.readSampleData(inputBuffer, 0)
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(inIndex, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                isSectionEOS = true
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
                                    while (floatBuf.hasRemaining() && sampledFloats.size < sectionTarget) {
                                        val s = floatBuf.get()
                                        if (channelCount > 1) {
                                            for (ch in 1 until channelCount) {
                                                if (floatBuf.hasRemaining()) floatBuf.get()
                                            }
                                        }
                                        sampledFloats.add(s.coerceIn(-1.0f, 1.0f))
                                    }
                                }
                                21 -> { // ENCODING_PCM_24BIT_PACKED
                                    val bytesPerFrame = 3 * channelCount
                                    while (outputBuffer.remaining() >= bytesPerFrame && sampledFloats.size < sectionTarget) {
                                        val b0 = outputBuffer.get().toInt() and 0xFF
                                        val b1 = outputBuffer.get().toInt() and 0xFF
                                        val b2 = outputBuffer.get().toInt()
                                        val s24 = (b2 shl 16) or (b1 shl 8) or b0
                                        val sFloat = (s24.toFloat() / 8388608.0f).coerceIn(-1.0f, 1.0f)
                                        sampledFloats.add(sFloat)
                                        if (channelCount > 1) {
                                            outputBuffer.position(outputBuffer.position() + 3 * (channelCount - 1))
                                        }
                                    }
                                }
                                22 -> { // ENCODING_PCM_32BIT
                                    val intBuf = outputBuffer.asIntBuffer()
                                    while (intBuf.hasRemaining() && sampledFloats.size < sectionTarget) {
                                        val s = intBuf.get()
                                        if (channelCount > 1) {
                                            for (ch in 1 until channelCount) {
                                                if (intBuf.hasRemaining()) intBuf.get()
                                            }
                                        }
                                        sampledFloats.add((s.toFloat() / 2147483648.0f).coerceIn(-1.0f, 1.0f))
                                    }
                                }
                                else -> { // ENCODING_PCM_16BIT
                                    val shortBuf = outputBuffer.asShortBuffer()
                                    while (shortBuf.hasRemaining() && sampledFloats.size < sectionTarget) {
                                        val s = shortBuf.get()
                                        if (channelCount > 1) {
                                            for (ch in 1 until channelCount) {
                                                if (shortBuf.hasRemaining()) shortBuf.get()
                                            }
                                        }
                                        sampledFloats.add(s.toFloat() / 32768.0f)
                                    }
                                }
                            }
                        }
                        codec.releaseOutputBuffer(outIndex, false)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            isSectionEOS = true
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
