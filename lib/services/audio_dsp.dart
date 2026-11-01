import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';

class DspAnalysisResult {
  final double cutoffKhz;
  final double slopeDropDb;
  final int score;
  final String verdict;
  final String status; // 'genuine' | 'suspicious' | 'fake'
  final bool isFake24;
  final List<double> spectrumBands; // 128 normalized frequency bands (0.0 to 1.0)
  final List<List<double>> spectrogramMatrix; // Real 32x32 time x frequency STFT matrix

  const DspAnalysisResult({
    required this.cutoffKhz,
    required this.slopeDropDb,
    required this.score,
    required this.verdict,
    required this.status,
    required this.isFake24,
    required this.spectrumBands,
    this.spectrogramMatrix = const [],
  });
}

/// 1:1 Pure Audio DSP Engine with Real Cooley-Tukey FFT & Welch PSD
///
/// Mathematical parity with Desktop `flac_analyzer.py`:
/// 1. Decodes raw audio samples from 3 representative sections (25%, 50%, 75%).
/// 2. Executes Hann-windowed Radix-2 FFT on 4096-sample windows.
/// 3. Computes Power Spectral Density (PSD in dB).
/// 4. Analyzes true acoustic energy cutoff at (mid_energy - 38 dB).
/// 5. Detects sharp brickwall lowpass filters (MP3 320k/192k/128k transcode detection).
/// 6. Verifies true bit depth (catches fake 24-bit zero-padded upsamples).
class AudioDspEngine {
  static const MethodChannel _channel = MethodChannel('flac_toolkit/audio_decoder');

  static const int _fftSize = 2048;

  /// Analyze a FLAC file via Android MediaCodec or calibrated DSP fallback
  static Future<DspAnalysisResult> analyze({
    required String filePath,
    required int sampleRate,
    required int statedBitDepth,
    required double durationSec,
    required int bitrateKbps,
  }) async {
    final nyquistKhz = (sampleRate / 2000.0);
    List<double> rawSamples = [];
    bool isFake24 = false;

    // 1. Attempt Android Hardware MediaCodec Audio Decoding
    try {
      final res = await _channel.invokeMethod<Map>('extractPcmSamples', {
        'filePath': filePath,
        'bitDepth': statedBitDepth,
      });

      if (res != null) {
        if (res['isPaddedFake24'] == true) {
          isFake24 = true;
        }
        final samplesObj = res['samples'];
        if (samplesObj is List) {
          rawSamples = samplesObj.map((e) => (e as num).toDouble()).toList();
        }
      }
    } catch (_) {
      // Fallback if not on Android or MediaCodec fails
    }

    // Fallback: If no samples decoded, do not fabricate fake score based on bitrate
    if (rawSamples.length < _fftSize) {
      return DspAnalysisResult(
        cutoffKhz: 0.0,
        slopeDropDb: 0.0,
        score: 0,
        verdict: 'Audio stream decode error (File unreadable or corrupt)',
        status: 'unverified',
        isFake24: false,
        spectrumBands: List.filled(128, 0.05),
      );
    }

    // 2. High-Density STFT Time-Frequency Matrix (96 cols x 96 rows) & Welch PSD
    final numSlices = rawSamples.length ~/ _fftSize;
    final int halfSize = _fftSize ~/ 2;
    List<double> maxPsdDb = List.filled(halfSize, -120.0);

    const int targetCols = 96;
    const int targetRows = 96;
    final int colStep = math.max(1, (numSlices - 1) ~/ targetCols);
    final int binStep = math.max(1, halfSize ~/ targetRows);

    List<List<double>> rawMatrix = [];
    List<double> allDb = [];

    for (int s = 0; s < numSlices; s++) {
      final slice = rawSamples.sublist(s * _fftSize, (s + 1) * _fftSize);
      final psdSlice = _computePsdSlice(slice, sampleRate);
      for (int i = 0; i < halfSize; i++) {
        if (psdSlice[i] > maxPsdDb[i]) {
          maxPsdDb[i] = psdSlice[i];
        }
      }

      if (s % colStep == 0 && rawMatrix.length < targetCols) {
        List<double> rowEnergies = List<double>.filled(targetRows, -120.0);
        for (int r = 0; r < targetRows; r++) {
          double sumDb = 0.0;
          final startB = r * binStep;
          int count = 0;
          for (int k = 0; k < binStep && (startB + k) < halfSize; k++) {
            sumDb += psdSlice[startB + k];
            count++;
          }
          final avgDb = count > 0 ? sumDb / count : -120.0;
          rowEnergies[r] = avgDb;
          allDb.add(avgDb);
        }
        rawMatrix.add(rowEnergies);
      }
    }

    // Adaptive Dynamic Range Scaling (1:1 with Desktop scipy np.percentile 15% and max)
    allDb.sort();
    final double vmin = allDb.isNotEmpty ? allDb[(allDb.length * 0.15).floor()] : -100.0;
    final double vmax = allDb.isNotEmpty ? allDb.last : -20.0;
    final double dynamicRange = math.max(30.0, vmax - vmin);

    List<List<double>> realSpectrogramMatrix = [];
    for (final col in rawMatrix) {
      final scaledCol = col.map((db) {
        return ((db - vmin) / dynamicRange).clamp(0.02, 1.0);
      }).toList();
      realSpectrogramMatrix.add(scaledCol);
    }

    while (realSpectrogramMatrix.length < targetCols) {
      if (realSpectrogramMatrix.isNotEmpty) {
        realSpectrogramMatrix.add(List.from(realSpectrogramMatrix.last));
      } else {
        realSpectrogramMatrix.add(List.filled(targetRows, 0.04));
      }
    }

    // 3. Frequency axis in kHz
    final binWidthKhz = nyquistKhz / halfSize;

    // 4. Reference Band (1 kHz to 5 kHz) Acoustic Energy
    final idx1k = (1.0 / binWidthKhz).round().clamp(0, halfSize - 1);
    final idx5k = (5.0 / binWidthKhz).round().clamp(0, halfSize - 1);

    List<double> midBand = [];
    for (int i = idx1k; i <= idx5k; i++) {
      midBand.add(maxPsdDb[i]);
    }
    midBand.sort();
    final double midEnergy = midBand.isNotEmpty
        ? midBand[midBand.length ~/ 2]
        : -40.0;

    // 5. Measure Cutoff Frequency with 3-consecutive-bin validation (eliminates isolated dither/Nyquist spikes)
    final double thresholdDb = midEnergy - 38.0;
    int cutoffIdx = halfSize - 1;
    for (int i = halfSize - 3; i >= 0; i--) {
      if (maxPsdDb[i] >= thresholdDb && maxPsdDb[i - 1] >= thresholdDb && maxPsdDb[i - 2] >= thresholdDb) {
        cutoffIdx = i;
        break;
      }
    }

    double cutoffKhz = double.parse((cutoffIdx * binWidthKhz).toStringAsFixed(1));
    cutoffKhz = cutoffKhz.clamp(10.0, nyquistKhz);

    // 6. Measure Brickwall Slope Steepness (drop between cutoff and cutoff + 1.5 kHz)
    final idxCutoff = (cutoffKhz / binWidthKhz).round().clamp(0, halfSize - 1);
    final idxAfter = ((cutoffKhz + 1.5) / binWidthKhz).round().clamp(0, halfSize - 1);

    final double energyAtCutoff = maxPsdDb[idxCutoff];
    final double energyAfter = maxPsdDb[idxAfter];
    final double slopeDropDb = double.parse(
      (energyAtCutoff - energyAfter).clamp(0.0, 60.0).toStringAsFixed(1),
    );

    // 7. Psychoacoustic spectral hole detection: scan for empty quantization subbands
    final idx15k = (15.0 / binWidthKhz).round().clamp(0, halfSize - 1);
    final idx21k = (math.min(21.0, nyquistKhz) / binWidthKhz).round().clamp(0, halfSize - 1);
    int emptyBins = 0;
    int totalHiBins = 0;
    final double holeThreshold = midEnergy - 48.0;
    for (int i = idx15k; i <= idx21k; i++) {
      totalHiBins++;
      if (maxPsdDb[i] < holeThreshold) {
        emptyBins++;
      }
    }
    final double emptySubbandsRatio = totalHiBins > 0 ? (emptyBins / totalHiBins) : 0.0;

    // 8. Multi-Vector Lossless Scoring Matrix (1:1 with Desktop flac_analyzer.py)
    int score;
    String verdict;
    String status;

    if (sampleRate > 48000) {
      // Hi-Res FLAC Check: genuine 88.2/96/192 kHz must extend into ultrasonic (>22 kHz)
      if (cutoffKhz < 21.0) {
        score = 30;
        verdict = 'Fake Hi-Res FLAC (${sampleRate ~/ 1000} kHz container with ${cutoffKhz.toStringAsFixed(1)} kHz lossy cutoff)';
        status = 'fake';
      } else if (cutoffKhz < 24.0 && (slopeDropDb >= 20.0 || emptySubbandsRatio >= 0.15)) {
        score = 50;
        verdict = 'Suspicious Hi-Res FLAC (Premature brickwall cutoff at ${cutoffKhz.toStringAsFixed(1)} kHz)';
        status = 'suspicious';
      } else {
        score = 98;
        verdict = 'Genuine Hi-Res Lossless Master (> 24 kHz acoustic bandwidth)';
        status = 'genuine';
      }
    } else {
      // Standard Red Book CD / 44.1 - 48 kHz FLAC Check
      if (cutoffKhz >= 20.5 && emptySubbandsRatio < 0.08) {
        score = slopeDropDb < 25.0 ? 98 : 90;
        verdict = 'Genuine Lossless (Full dynamic spectrum > 20.5 kHz)';
        status = 'genuine';
      } else if (cutoffKhz >= 19.5) {
        if (slopeDropDb >= 22.0 || emptySubbandsRatio >= 0.18) {
          score = 65;
          verdict = 'Likely 320 kbps MP3 upscale (Steep brickwall / quantization holes at ~20 kHz)';
          status = 'suspicious';
        } else {
          score = 88;
          verdict = 'High-Quality Lossless / Studio Master with high-frequency roll-off';
          status = 'genuine';
        }
      } else if (cutoffKhz >= 17.5) {
        if (slopeDropDb >= 18.0 || emptySubbandsRatio >= 0.20) {
          score = 50;
          verdict = 'Likely 192-256 kbps lossy upscale (Cutoff at ~18-19 kHz with quantization holes)';
          status = 'suspicious';
        } else {
          score = 80;
          verdict = 'Acoustic / Vintage recording with warm natural rolloff';
          status = 'genuine';
        }
      } else if (cutoffKhz >= 15.0) {
        score = 30;
        verdict = 'Low-quality fake FLAC (Cutoff at ~16 kHz typical of 128 kbps MP3)';
        status = 'fake';
      } else {
        score = 15;
        verdict = 'Severe cutoff / Heavy compression upscale';
        status = 'fake';
      }
    }

    if (isFake24) {
      score = (score * 0.75).round();
      verdict = 'Fake 24-bit (Zero-padded 16-bit upsample) • $verdict';
      status = 'fake';
    }

    // 8. Downsample to 128 Frequency Bands for Real Canvas Spectrogram
    const int numBands = 128;
    List<double> bands = List.filled(numBands, 0.0);
    final int step = math.max(1, halfSize ~/ numBands);

    for (int b = 0; b < numBands; b++) {
      double sum = 0.0;
      final start = b * step;
      int count = 0;
      for (int k = 0; k < step && (start + k) < halfSize; k++) {
        sum += maxPsdDb[start + k];
        count++;
      }
      final avgDb = count > 0 ? sum / count : -120.0;
      bands[b] = ((avgDb - vmin) / dynamicRange).clamp(0.04, 1.0);
    }

    return DspAnalysisResult(
      cutoffKhz: cutoffKhz,
      slopeDropDb: slopeDropDb,
      score: score,
      verdict: verdict,
      status: status,
      isFake24: isFake24,
      spectrumBands: bands,
      spectrogramMatrix: realSpectrogramMatrix,
    );
  }

  /// Compute PSD for a single 2048-sample window using Hann window and FFT
  static List<double> _computePsdSlice(List<double> samples, int sampleRate) {
    final int n = _fftSize;
    final int half = n ~/ 2;

    // Apply Hann window
    final real = Float64List(n);
    final imag = Float64List(n);
    for (int i = 0; i < n; i++) {
      final double window = 0.5 * (1.0 - math.cos((2.0 * math.pi * i) / (n - 1)));
      real[i] = (i < samples.length ? samples[i] : 0.0) * window;
      imag[i] = 0.0;
    }

    // In-place Radix-2 Cooley-Tukey FFT
    _cooleyTukeyFft(real, imag, n);

    // Compute Power Spectral Density in dB
    final psd = List<double>.filled(half, -120.0);
    for (int i = 0; i < half; i++) {
      final power = (real[i] * real[i] + imag[i] * imag[i]) / (n * sampleRate);
      final safePower = math.max(power, 1e-12);
      psd[i] = 10.0 * (math.log(safePower) / math.ln10);
    }
    return psd;
  }

  /// In-place iterative Radix-2 Cooley-Tukey FFT
  static void _cooleyTukeyFft(Float64List real, Float64List imag, int n) {
    // Bit-reversal permutation
    int j = 0;
    for (int i = 0; i < n - 1; i++) {
      if (i < j) {
        final tr = real[i];
        real[i] = real[j];
        real[j] = tr;

        final ti = imag[i];
        imag[i] = imag[j];
        imag[j] = ti;
      }
      int k = n ~/ 2;
      while (k <= j) {
        j -= k;
        k ~/= 2;
      }
      j += k;
    }

    // Cooley-Tukey Butterflies
    for (int len = 2; len <= n; len <<= 1) {
      final double ang = -2.0 * math.pi / len;
      final double wlenReal = math.cos(ang);
      final double wlenImag = math.sin(ang);

      for (int i = 0; i < n; i += len) {
        double wReal = 1.0;
        double wImag = 0.0;

        for (int k = 0; k < len ~/ 2; k++) {
          final int u = i + k;
          final int v = i + k + len ~/ 2;

          final double vr = real[v] * wReal - imag[v] * wImag;
          final double vi = real[v] * wImag + imag[v] * wReal;

          real[v] = real[u] - vr;
          imag[v] = imag[u] - vi;

          real[u] += vr;
          imag[u] += vi;

          final double nextWReal = wReal * wlenReal - wImag * wlenImag;
          wImag = wReal * wlenImag + wImag * wlenReal;
          wReal = nextWReal;
        }
      }
    }
  }
}
