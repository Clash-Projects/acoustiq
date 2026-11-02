import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../models/flac_info.dart';
import 'audio_dsp.dart';

class FlacParser {
  static Future<FlacInfo> analyzeFile(String filePath) async {
    final file = File(filePath);
    final fileName = p.basename(filePath);
    final stem = p.basenameWithoutExtension(filePath);

    if (!await file.exists()) {
      return FlacInfo.withError(filePath, fileName, 'File not found');
    }

    final fileSize = await file.length();
    final fileSizeMb = double.parse((fileSize / (1024 * 1024)).toStringAsFixed(2));

    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);

      // Verify FLAC magic header 'fLaC'
      final magic = await raf.read(4);
      if (magic.length < 4 ||
          magic[0] != 0x66 || // 'f'
          magic[1] != 0x4C || // 'L'
          magic[2] != 0x61 || // 'a'
          magic[3] != 0x43) { // 'C'
        return FlacInfo.withError(filePath, fileName, 'Not a valid FLAC file (missing magic header)');
      }

      int sampleRate = 44100;
      int channels = 2;
      int bitDepth = 16;
      int totalSamples = 0;
      bool hasStreamInfo = false;

      final Map<String, String> tags = {};
      bool hasCover = false;
      Uint8List? coverBytes;

      while (true) {
        final header = await raf.read(4);
        if (header.length < 4) break;

        final isLast = (header[0] & 0x80) != 0;
        final blockType = header[0] & 0x7F;
        final blockLen = (header[1] << 16) | (header[2] << 8) | header[3];

        if (blockType == 0) {
          // METADATA_BLOCK_STREAMINFO
          final data = await raf.read(blockLen);
          if (data.length >= 18) {
            sampleRate = (data[10] << 12) | (data[11] << 4) | (data[12] >> 4);
            channels = ((data[12] >> 1) & 0x07) + 1;
            bitDepth = (((data[12] & 0x01) << 4) | (data[13] >> 4)) + 1;
            totalSamples = ((data[13] & 0x0F) << 32) |
                (data[14] << 24) |
                (data[15] << 16) |
                (data[16] << 8) |
                data[17];
            hasStreamInfo = true;
          }
        } else if (blockType == 4) {
          // METADATA_BLOCK_VORBIS_COMMENT
          final data = await raf.read(blockLen);
          if (data.length >= 8) {
            final bd = ByteData.sublistView(data);
            int pos = 0;
            final vendorLen = bd.getUint32(pos, Endian.little);
            pos += 4 + vendorLen;

            if (pos + 4 <= data.length) {
              final count = bd.getUint32(pos, Endian.little);
              pos += 4;

              for (int i = 0; i < count; i++) {
                if (pos + 4 > data.length) break;
                final clen = bd.getUint32(pos, Endian.little);
                pos += 4;
                if (pos + clen > data.length) break;

                final comment = utf8.decode(data.sublist(pos, pos + clen), allowMalformed: true);
                pos += clen;

                final eqIdx = comment.indexOf('=');
                if (eqIdx != -1) {
                  final k = comment.substring(0, eqIdx).trim().toLowerCase();
                  final v = comment.substring(eqIdx + 1).trim();
                  tags[k] = v;
                }
              }
            }
          }
        } else if (blockType == 6) {
          // METADATA_BLOCK_PICTURE
          hasCover = true;
          if (coverBytes == null && blockLen < 5 * 1024 * 1024) {
            // Read cover image bytes (limit to 5MB)
            final data = await raf.read(blockLen);
            if (data.length >= 32) {
              final bd = ByteData.sublistView(data);
              int pos = 4; // Skip picture type (32 bit)
              final mimeLen = bd.getUint32(pos, Endian.big);
              pos += 4 + mimeLen;
              if (pos + 4 <= data.length) {
                final descLen = bd.getUint32(pos, Endian.big);
                pos += 4 + descLen;
                pos += 16; // width (4), height (4), depth (4), colors (4)
                if (pos + 4 <= data.length) {
                  final dataLen = bd.getUint32(pos, Endian.big);
                  pos += 4;
                  if (pos + dataLen <= data.length) {
                    coverBytes = Uint8List.fromList(data.sublist(pos, pos + dataLen));
                  }
                }
              }
            }
          } else {
            await raf.setPosition((await raf.position()) + blockLen);
          }
        } else {
          // Skip other metadata blocks
          await raf.setPosition((await raf.position()) + blockLen);
        }

        if (isLast) break;
      }

      if (!hasStreamInfo) {
        return FlacInfo.withError(filePath, fileName, 'Invalid FLAC: Missing STREAMINFO block');
      }

      double durationSec = 0.0;
      if (sampleRate > 0 && totalSamples > 0) {
        durationSec = totalSamples / sampleRate;
      }

      final mins = durationSec ~/ 60;
      final secs = (durationSec % 60).toInt();
      final durationStr = '${mins}m ${secs.toString().padLeft(2, '0')}s';

      int bitrateKbps = 0;
      if (durationSec > 0) {
        bitrateKbps = ((fileSize * 8) / durationSec / 1000).round();
      }

      final title = tags['title'] ?? stem;
      final artist = tags['artist'] ?? 'Unknown Artist';
      final album = tags['album'] ?? 'Unknown Album';
      final lyrics = tags['lyrics'] ?? tags['unsyncedlyrics'];
      final hasLyrics = lyrics != null && lyrics.trim().isNotEmpty;

      // Close random access file before running decoder on the file
      await raf?.close();
      raf = null;

      // Real DSP Forensic Frequency & Cutoff Analysis (Desktop Parity)
      final dspResult = await AudioDspEngine.analyze(
        filePath: filePath,
        sampleRate: sampleRate,
        statedBitDepth: bitDepth,
        durationSec: durationSec,
        bitrateKbps: bitrateKbps,
      );

      return FlacInfo(
        filePath: filePath,
        fileName: fileName,
        fileSizeMb: fileSizeMb,
        title: title,
        artist: artist,
        album: album,
        sampleRate: sampleRate,
        bitDepth: bitDepth,
        channels: channels,
        durationSec: durationSec,
        durationStr: durationStr,
        bitrateKbps: bitrateKbps,
        hasCover: hasCover,
        coverBytes: coverBytes,
        cutoffKhz: dspResult.cutoffKhz,
        maxKhz: dspResult.displayMaxKhz,
        slopeDropDb: dspResult.slopeDropDb,
        score: dspResult.score,
        verdict: dspResult.verdict,
        status: dspResult.status,
        isFake24: dspResult.isFake24,
        spectrumBands: dspResult.spectrumBands,
        spectrogramMatrix: dspResult.spectrogramMatrix,
        hasLyrics: hasLyrics,
        lyricsText: lyrics,
      );
    } catch (e) {
      return FlacInfo.withError(filePath, fileName, 'Read error: $e');
    } finally {
      await raf?.close();
    }
  }
}

