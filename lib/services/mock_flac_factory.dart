import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/flac_info.dart';

/// AcoustiQ Developer Laboratory & QA Factory
///
/// Generates instant, deterministic mock FLAC tracks covering all edge cases:
/// 1. Genuine 96kHz / 24-bit Hi-Res master with rich ultrasonic harmonics.
/// 2. Fake 96kHz FLAC (lossy 16kHz MP3 upsample).
/// 3. Extreme 160-character title with Hindi Devanagari lyrics to stress-test viewport truncation.
/// 4. Rich multi-verse synchronized LRC track for instant lyrics auto-scrolling QA.
class MockFlacFactory {
  /// Generate a realistic 32x32 STFT spectrogram matrix
  static List<List<double>> _generateSpectrogram({
    required double cutoffKhz,
    required double maxKhz,
    required bool isGenuine,
  }) {
    const int timeSlices = 32;
    const int freqBins = 32;
    final double cutoffRatio = (cutoffKhz / maxKhz).clamp(0.0, 1.0);
    final random = math.Random(42);

    List<List<double>> matrix = [];
    for (int t = 0; t < timeSlices; t++) {
      List<double> column = List.filled(freqBins, 0.0);
      for (int f = 0; f < freqBins; f++) {
        final double freqRatio = f / freqBins;
        if (freqRatio > cutoffRatio) {
          // Dead zone
          column[f] = 0.02 + (random.nextDouble() * 0.03);
        } else {
          final double base = (1.0 - (freqRatio * 0.70)).clamp(0.15, 0.95);
          final double wave = 0.85 + (math.sin(t * 0.4 + f * 0.2) * 0.15);
          column[f] = (base * wave).clamp(0.04, 0.98);
        }
      }
      matrix.add(column);
    }
    return matrix;
  }

  /// Generate 128 frequency bands
  static List<double> _generateBands(double cutoffKhz, double maxKhz) {
    const int numBands = 128;
    final double cutoffRatio = (cutoffKhz / maxKhz).clamp(0.0, 1.0);
    List<double> bands = List.filled(numBands, 0.0);
    for (int i = 0; i < numBands; i++) {
      final ratio = i / numBands;
      if (ratio > cutoffRatio) {
        bands[i] = 0.04;
      } else {
        bands[i] = (1.0 - (ratio * 0.65)).clamp(0.12, 1.0);
      }
    }
    return bands;
  }

  /// Mock 1: Genuine 96kHz / 24-bit Hi-Res Master
  static FlacInfo createMockGenuineHiRes() {
    return FlacInfo(
      filePath: '/storage/emulated/0/Music/AcoustiQ_Reference_HiRes.flac',
      fileName: 'AcoustiQ_Reference_HiRes.flac',
      fileSizeMb: 68.4,
      title: 'Acoustic Prism (Hi-Res Studio Master)',
      artist: 'AcoustiQ Acoustic Labs',
      album: 'Reference Audiophile Showcase Vol. 1',
      sampleRate: 96000,
      bitDepth: 24,
      channels: 2,
      durationSec: 214.0,
      durationStr: '03:34',
      bitrateKbps: 2845,
      hasCover: true,
      cutoffKhz: 28.5,
      maxKhz: 48.0,
      slopeDropDb: 4.2,
      score: 98,
      verdict: 'Genuine Hi-Res Lossless Master (> 24 kHz acoustic bandwidth)',
      status: 'genuine',
      isFake24: false,
      hasLyrics: true,
      lyricsText: _syncedLrcMock,
      spectrumBands: _generateBands(28.5, 48.0),
      spectrogramMatrix: _generateSpectrogram(cutoffKhz: 28.5, maxKhz: 48.0, isGenuine: true),
    );
  }

  /// Mock 2: Fake 96kHz FLAC (Transcoded from 128k MP3)
  static FlacInfo createMockFakeUpsample() {
    return FlacInfo(
      filePath: '/storage/emulated/0/Download/Pirated_Web_Rip_96k.flac',
      fileName: 'Pirated_Web_Rip_96k.flac',
      fileSizeMb: 52.1,
      title: 'Fake 96kHz Master (Upsampled MP3)',
      artist: 'Lossy Transcoder Network',
      album: 'Transcode Hall of Shame',
      sampleRate: 96000,
      bitDepth: 24,
      channels: 2,
      durationSec: 182.0,
      durationStr: '03:02',
      bitrateKbps: 2150,
      hasCover: false,
      cutoffKhz: 16.0,
      maxKhz: 48.0,
      slopeDropDb: 38.5,
      score: 28,
      verdict: 'Fake Hi-Res FLAC (96 kHz container with 16.0 kHz MP3 brickwall cutoff)',
      status: 'fake',
      isFake24: false,
      hasLyrics: false,
      spectrumBands: _generateBands(16.0, 48.0),
      spectrogramMatrix: _generateSpectrogram(cutoffKhz: 16.0, maxKhz: 48.0, isGenuine: false),
    );
  }

  /// Mock 3: Extreme Long Title with Hindi Devanagari Lyrics (Truncation Stress-Test)
  static FlacInfo createMockLongTitleOverflow() {
    return FlacInfo(
      filePath: '/storage/emulated/0/Music/Long_Title_Stress_Test.flac',
      fileName: 'Long_Title_Stress_Test.flac',
      fileSizeMb: 42.8,
      title: 'Shree Krishna Govind Hare Murari Hey Nath Narayan Vasudeva Radhe Krishna Gopal Hari Shree Radhe Radhe Barsane Wali',
      artist: 'Devotional Symphony Orchestra & Traditional Choir of Vrindavan Dham',
      album: 'Immortal Bhajans & Meditative Chants Collection (Deluxe Audiophile Edition)',
      sampleRate: 44100,
      bitDepth: 16,
      channels: 2,
      durationSec: 420.0,
      durationStr: '07:00',
      bitrateKbps: 912,
      hasCover: true,
      cutoffKhz: 20.8,
      maxKhz: 22.0,
      slopeDropDb: 2.1,
      score: 95,
      verdict: 'Genuine CD-Quality Lossless Audio (Full 20 kHz acoustic bandwidth)',
      status: 'genuine',
      isFake24: false,
      hasLyrics: true,
      lyricsText: _hindiDevanagariLrcMock,
      spectrumBands: _generateBands(20.8, 22.0),
      spectrogramMatrix: _generateSpectrogram(cutoffKhz: 20.8, maxKhz: 22.0, isGenuine: true),
    );
  }

  /// Mock 4: Rich Multi-Verse Synced LRC Song (For Lyrics Scroll QA)
  static FlacInfo createMockSyncedLyricsTrack() {
    return FlacInfo(
      filePath: '/storage/emulated/0/Music/Synced_Lyrics_Showcase.flac',
      fileName: 'Synced_Lyrics_Showcase.flac',
      fileSizeMb: 35.6,
      title: 'Shree Krishna Govind Hare Murari',
      artist: 'Acoustic Devotional Ensemble',
      album: 'Sacred Soundscapes Vol. 3',
      sampleRate: 48000,
      bitDepth: 24,
      channels: 2,
      durationSec: 165.0,
      durationStr: '02:45',
      bitrateKbps: 1540,
      hasCover: true,
      cutoffKhz: 22.5,
      maxKhz: 24.0,
      slopeDropDb: 3.0,
      score: 96,
      verdict: 'Genuine 48kHz Studio Lossless (Full Nyquist bandwidth)',
      status: 'genuine',
      isFake24: false,
      hasLyrics: true,
      lyricsText: _hindiDevanagariLrcMock,
      spectrumBands: _generateBands(22.5, 24.0),
      spectrogramMatrix: _generateSpectrogram(cutoffKhz: 22.5, maxKhz: 24.0, isGenuine: true),
    );
  }

  static const String _syncedLrcMock = '''
[00:00.00] ♪ Prismatic Studio Introduction ♪
[00:04.20] In the quiet glow of obsidian glass
[00:08.50] Light refracts through the acoustic prism
[00:13.10] Frequencies extend beyond the human ear
[00:18.00] Pure uncompressed PCM bitstream
[00:23.50] ♪ Dynamic Cello & Sub-Bass Solo ♪
[00:30.00] Twenty-four bits of dynamic resolution
[00:35.20] No quantization noise or harmonic holes
[00:40.80] The studio master breathes with clarity
[00:46.40] Exactly as the acoustic engineer mixed
[00:52.00] ♪ Harmonic Violin Crescendo ♪
[01:00.00] Every transient attack is preserved
[01:06.00] From the lowest kick to ultrasonic air
[01:12.50] This is the truth in lossless sound
[01:18.00] AcoustiQ Studio Reference
[01:25.00] ♪ Ambient Glass Reverberation ♪
''';

  static const String _hindiDevanagariLrcMock = '''
[00:00.00] ♪ मधुर बांसुरी वादन - परिचय ♪
[00:04.50] श्री कृष्ण गोविंद हरे मुरारी
[00:09.20] हे नाथ नारायण वासुदेवा
[00:14.00] राधे कृष्ण गोपाल हरी
[00:18.80] हे नाथ नारायण वासुदेवा
[00:24.10] ♪ शास्त्रीय सितार व तबला जुगलबंदी ♪
[00:30.00] माखन चोरी लीला मन भाई
[00:34.50] बृज मंडल में मुरली बजाई
[00:39.20] यमुना तट पर धेनु चरावे
[00:44.00] सब सखियों के मन को भावे
[00:50.00] श्री कृष्ण गोविंद हरे मुरारी
[00:55.50] हे नाथ नारायण वासुदेवा
[01:02.00] ♪ मधुर शंख ध्वनि व विराम ♪
[01:08.50] दीन दयाल कृपा अब कीजै
[01:14.00] भव सागर से पार करीजै
[01:19.50] राधा रानी संग विराजे
[01:25.00] चरण कमल में शीश नवाजे
[01:31.00] श्री कृष्ण गोविंद हरे मुरारी
[01:37.00] हे नाथ नारायण वासुदेवा
[01:45.00] ♪ आध्यात्मिक समापन धुन ♪
''';
}
