import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flac_toolkit/services/audio_dsp.dart';

List<double> _generateBroadbandSignal({
  required int sampleRate,
  required int sampleCount,
  required double maxToneHz,
}) {
  final out = List<double>.filled(sampleCount, 0.0);
  // Dense broadband comb (~85 Hz spacing) so 1-5 kHz reference band reflects realistic spectrum energy
  final freqs = <double>[];
  for (double f = 200; f <= maxToneHz; f += 85) {
    freqs.add(f);
  }

  for (int i = 0; i < sampleCount; i++) {
    final t = i / sampleRate;
    double acc = 0.0;
    for (int j = 0; j < freqs.length; j++) {
      acc += math.sin(2.0 * math.pi * freqs[j] * t + (j * 0.37));
    }
    out[i] = acc / freqs.length;
  }
  return out;
}

void main() {
  group('AudioDspEngine Cooley-Tukey FFT & Welch PSD', () {
    test('detects genuine full-bandwidth signal above 20 kHz', () {
      final samples = _generateBroadbandSignal(
        sampleRate: 44100,
        sampleCount: 4096 * 3,
        maxToneHz: 21500,
      );

      final result = AudioDspEngine.analyzePcmSamplesForTesting(
        rawSamples: samples,
        sampleRate: 44100,
        statedBitDepth: 16,
      );

      expect(result.cutoffKhz, greaterThanOrEqualTo(20.0));
      expect(result.score, greaterThanOrEqualTo(80));
      expect(result.status, 'genuine');
      expect(result.spectrumBands.length, 128);
    });

    test('flags brickwall 16 kHz cutoff MP3 transcode properly', () {
      final samples = _generateBroadbandSignal(
        sampleRate: 44100,
        sampleCount: 4096 * 3,
        maxToneHz: 15800,
      );

      final result = AudioDspEngine.analyzePcmSamplesForTesting(
        rawSamples: samples,
        sampleRate: 44100,
        statedBitDepth: 16,
      );

      expect(result.cutoffKhz, lessThanOrEqualTo(16.8));
      expect(result.status, isNot('genuine'));
      expect(result.score, lessThan(80));
    });
  });
}
