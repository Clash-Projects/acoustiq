import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flac_toolkit/services/flac_parser.dart';

Uint8List _buildSyntheticFlac({
  int sampleRate = 96000,
  int channels = 2,
  int bitDepth = 24,
  int totalSamples = 96000 * 120,
  List<int>? md5Bytes,
  Map<String, String> tags = const {
    'TITLE': 'Midnight PCM',
    'ARTIST': 'Clash Test',
    'ALBUM': 'Benchmarks',
    'LYRICS': '[00:01.00]Pure tone',
  },
}) {
  final out = BytesBuilder();
  out.add([0x66, 0x4C, 0x61, 0x43]); // 'fLaC'

  // STREAMINFO block (type 0, length 34)
  final streamInfo = Uint8List(34);
  // min/max block & frame sizes left zero; sampleRate(20b) | channels-1(3b) | bitDepth-1(5b) | totalSamples(36b)
  streamInfo[10] = (sampleRate >> 12) & 0xFF;
  streamInfo[11] = (sampleRate >> 4) & 0xFF;
  streamInfo[12] = ((sampleRate & 0x0F) << 4) | (((channels - 1) & 0x07) << 1) | (((bitDepth - 1) >> 4) & 0x01);
  streamInfo[13] = (((bitDepth - 1) & 0x0F) << 4) | ((totalSamples >> 32) & 0x0F);
  streamInfo[14] = (totalSamples >> 24) & 0xFF;
  streamInfo[15] = (totalSamples >> 16) & 0xFF;
  streamInfo[16] = (totalSamples >> 8) & 0xFF;
  streamInfo[17] = totalSamples & 0xFF;

  final md5 = md5Bytes ?? List<int>.generate(16, (i) => i + 1);
  for (int i = 0; i < 16; i++) {
    streamInfo[18 + i] = md5[i];
  }

  final hasTags = tags.isNotEmpty;
  out.add([hasTags ? 0x00 : 0x80, 0x00, 0x00, 34]);
  out.add(streamInfo);

  if (hasTags) {
    final vorbis = BytesBuilder();
    final vendorBytes = 'ClashVendor'.codeUnits;
    final lenBd = ByteData(4)..setUint32(0, vendorBytes.length, Endian.little);
    vorbis.add(lenBd.buffer.asUint8List());
    vorbis.add(vendorBytes);

    final cntBd = ByteData(4)..setUint32(0, tags.length, Endian.little);
    vorbis.add(cntBd.buffer.asUint8List());
    for (final entry in tags.entries) {
      final raw = '${entry.key}=${entry.value}'.codeUnits;
      final cBd = ByteData(4)..setUint32(0, raw.length, Endian.little);
      vorbis.add(cBd.buffer.asUint8List());
      vorbis.add(raw);
    }

    final vBytes = vorbis.toBytes();
    out.add([
      0x84, // isLast + VORBIS_COMMENT (4)
      (vBytes.length >> 16) & 0xFF,
      (vBytes.length >> 8) & 0xFF,
      vBytes.length & 0xFF,
    ]);
    out.add(vBytes);
  }

  return out.toBytes();
}

void main() {
  group('FlacParser binary STREAMINFO & Vorbis comments', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('acoustiq_flac_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('parses 24-bit/96kHz STREAMINFO, MD5, and Vorbis comments cleanly', () async {
      final path = '${tempDir.path}/master_24_96.flac';
      await File(path).writeAsBytes(_buildSyntheticFlac());

      final info = await FlacParser.analyzeFile(path, deepDsp: false);
      expect(info.error, isNull);
      expect(info.sampleRate, 96000);
      expect(info.bitDepth, 24);
      expect(info.channels, 2);
      expect(info.durationSec, closeTo(120.0, 0.01));
      expect(info.title, 'Midnight PCM');
      expect(info.artist, 'Clash Test');
      expect(info.album, 'Benchmarks');
      expect(info.hasLyrics, isTrue);
      expect(info.lyricsText, '[00:01.00]Pure tone');
      expect(info.audioMd5, '0102030405060708090a0b0c0d0e0f10');
    });

    test('rejects invalid non-FLAC magic header cleanly', () async {
      final path = '${tempDir.path}/not_a_flac.flac';
      await File(path).writeAsBytes([0x49, 0x44, 0x33, 0x03, 0x00]); // ID3 header

      final info = await FlacParser.analyzeFile(path, deepDsp: false);
      expect(info.error, isNotNull);
    });
  });
}
