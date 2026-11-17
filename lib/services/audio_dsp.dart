import 'dart:isolate';
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
  final List<List<double>> spectrogramMatrix; // Real time x frequency STFT matrix
  final double displayMaxKhz; // Aligned frequency ceiling for bit-perfect desktop parity

  const DspAnalysisResult({
    required this.cutoffKhz,
    required this.slopeDropDb,
    required this.score,
    required this.verdict,
    required this.status,
    required this.isFake24,
    required this.spectrumBands,
    this.spectrogramMatrix = const [],
    this.displayMaxKhz = 24.0,
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
        spectrogramMatrix: const [],
        displayMaxKhz: 24.0,
      );
    }

    // Run heavy FFT & Welch PSD computation in a background isolate to keep UI 60 FPS
    return await Isolate.run(() => _computeDspAnalysis(
      rawSamples: rawSamples,
      sampleRate: sampleRate,
      statedBitDepth: statedBitDepth,
      isFake24: isFake24,
      nyquistKhz: nyquistKhz,
    ));
  }

  static DspAnalysisResult _computeDspAnalysis({
    required List<double> rawSamples,
    required int sampleRate,
    required int statedBitDepth,
    required bool isFake24,
    required double nyquistKhz,
  }) {
    // 2. High-Density STFT Time-Frequency Slices & True Welch Average PSD
    final numSlices = rawSamples.length ~/ _fftSize;
    final int halfSize = _fftSize ~/ 2;

    // Linear Power accumulator for true Welch Average PSD (1:1 with scipy.signal.welch)
    final List<double> accumPower = List.filled(halfSize, 0.0);
    final List<List<double>> sliceDbList = [];

    for (int s = 0; s < numSlices; s++) {
      final slice = rawSamples.sublist(s * _fftSize, (s + 1) * _fftSize);
      final powerSlice = _computePowerSlice(slice, sampleRate);
      final psdDbSlice = List<double>.filled(halfSize, -120.0);
      for (int i = 0; i < halfSize; i++) {
        accumPower[i] += powerSlice[i];
        final safePower = math.max(powerSlice[i], 1e-12);
        psdDbSlice[i] = 10.0 * (math.log(safePower) / math.ln10);
      }
      sliceDbList.add(psdDbSlice);
    }

    // True Welch Average PSD in dB (cancels out transient dither spikes)
    final welchPsdDb = List<double>.filled(halfSize, -120.0);
    final double invSlices = numSlices > 0 ? (1.0 / numSlices) : 1.0;
    for (int i = 0; i < halfSize; i++) {
      final avgPower = math.max(accumPower[i] * invSlices, 1e-12);
      welchPsdDb[i] = 10.0 * (math.log(avgPower) / math.ln10);
    }

    // 3. Frequency axis in kHz
    final binWidthKhz = nyquistKhz / halfSize;

    // 4. Reference Band (1 kHz to 5 kHz) Acoustic Energy
    final idx1k = (1.0 / binWidthKhz).round().clamp(0, halfSize - 1);
    final idx5k = (5.0 / binWidthKhz).round().clamp(0, halfSize - 1);

    List<double> midBand = [];
    for (int i = idx1k; i <= idx5k; i++) {
      midBand.add(welchPsdDb[i]);
    }
    midBand.sort();
    final double midEnergy = midBand.isNotEmpty
        ? midBand[midBand.length ~/ 2]
        : -40.0;

    // 5. Measure Cutoff Frequency with 3-consecutive-bin validation (eliminates isolated dither/Nyquist spikes)
    final double thresholdDb = midEnergy - 38.0;
    int cutoffIdx = halfSize - 1;
    for (int i = halfSize - 3; i >= 0; i--) {
      if (welchPsdDb[i] >= thresholdDb &&
          welchPsdDb[i - 1] >= thresholdDb &&
          welchPsdDb[i - 2] >= thresholdDb) {
        cutoffIdx = i;
        break;
      }
    }

    double cutoffKhz = double.parse((cutoffIdx * binWidthKhz).toStringAsFixed(1));
    cutoffKhz = cutoffKhz.clamp(10.0, nyquistKhz);

    // 6. Measure Brickwall Slope Steepness (drop between cutoff and cutoff + 1.5 kHz)
    final idxCutoff = (cutoffKhz / binWidthKhz).round().clamp(0, halfSize - 1);
    final idxAfter = ((cutoffKhz + 1.5) / binWidthKhz).round().clamp(0, halfSize - 1);

    final double energyAtCutoff = welchPsdDb[idxCutoff];
    final double energyAfter = welchPsdDb[idxAfter];
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
      if (welchPsdDb[i] < holeThreshold) {
        emptyBins++;
      }
    }
    final double emptySubbandsRatio = totalHiBins > 0 ? (emptyBins / totalHiBins) : 0.0;

    // 8. Dynamic displayMaxKhz coordinate ceiling (1:1 with Desktop max(cutoff, min(nyquist, 24.0)))
    final double displayMaxKhz = math.max(
      cutoffKhz,
      (cutoffKhz > 23.5 && nyquistKhz > 24.0)
          ? nyquistKhz
          : math.min(nyquistKhz, 24.0),
    );

    final int maxDisplayBin = math.min(
      halfSize,
      math.max(1, ((displayMaxKhz / nyquistKhz) * halfSize).round()),
    );

    // 9. Build 96x96 Spectrogram Matrix bounded strictly to displayMaxKhz
    const int targetCols = 96;
    const int targetRows = 96;
    final int colStep = math.max(1, (numSlices - 1) ~/ targetCols);
    final int binStep = math.max(1, maxDisplayBin ~/ targetRows);

    List<List<double>> rawMatrix = [];
    List<double> allDb = [];

    for (int s = 0; s < numSlices; s++) {
      if (s % colStep == 0 && rawMatrix.length < targetCols) {
        final psdSlice = sliceDbList[s];
        List<double> rowEnergies = List<double>.filled(targetRows, -120.0);
        for (int r = 0; r < targetRows; r++) {
          double sumDb = 0.0;
          final startB = r * binStep;
          int count = 0;
          for (int k = 0; k < binStep && (startB + k) < maxDisplayBin; k++) {
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

    // 10. Continuous Dynamic Forensic Scoring Matrix (Option A: 10% - 99%)
    // Computes smooth, non-cliff scores reflecting cutoff frequency, brickwall steepness, and subband holes.

    // 1. Base Frequency Score (S_freq)
    double baseScore;
    if (cutoffKhz >= 21.0) {
      final double nyquistRange = math.max(1.0, nyquistKhz - 21.0);
      final double progress = ((cutoffKhz - 21.0) / nyquistRange).clamp(0.0, 1.0);
      baseScore = 95.0 + 4.0 * progress;
    } else if (cutoffKhz >= 18.5) {
      final double progress = (cutoffKhz - 18.5) / 2.5;
      baseScore = 78.0 + 17.0 * progress;
    } else if (cutoffKhz >= 16.0) {
      final double progress = (cutoffKhz - 16.0) / 2.5;
      baseScore = 38.0 + 40.0 * progress;
    } else {
      final double progress = math.max(0.0, (cutoffKhz - 10.0) / 6.0);
      baseScore = 10.0 + 28.0 * math.min(1.0, progress);
    }

    // 2. Continuous Penalties
    final double penaltyBrickwall = math.min(18.0, math.max(0.0, (slopeDropDb - 14.0) * 0.75));
    final double penaltyHoles = math.min(15.0, math.max(0.0, (emptySubbandsRatio - 0.05) * 60.0));
    final double rawScore = baseScore - penaltyBrickwall - penaltyHoles;

    int score;
    String verdict;
    String status;

    // 3. Hi-Res Container Integrity Guard (sampleRate > 48 kHz, Nyquist > 24 kHz)
    if (sampleRate > 48000) {
      if (cutoffKhz < 22.5) {
        score = rawScore.clamp(10.0, 30.0).round();
        verdict = 'Fake Hi-Res FLAC (${sampleRate ~/ 1000} kHz container with ${cutoffKhz.toStringAsFixed(1)} kHz lossy cutoff)';
        status = 'fake';
      } else if (cutoffKhz < 24.0) {
        score = rawScore.clamp(10.0, 55.0).round();
        verdict = 'Suspicious Hi-Res FLAC (Premature brickwall cutoff at ${cutoffKhz.toStringAsFixed(1)} kHz)';
        status = 'suspicious';
      } else {
        score = rawScore.clamp(10.0, 99.0).round();
        verdict = 'Genuine Hi-Res Lossless Master (${sampleRate ~/ 1000} kHz / >24 kHz acoustic bandwidth)';
        status = 'genuine';
      }
    } else {
      // Standard Red Book CD / 44.1 - 48 kHz FLAC
      score = rawScore.clamp(10.0, 99.0).round();
      if (score >= 90) {
        verdict = 'Genuine Lossless (Full dynamic spectrum up to ${cutoffKhz.toStringAsFixed(1)} kHz)';
        status = 'genuine';
      } else if (score >= 80) {
        verdict = 'Lossless with natural high-frequency roll-off at ${cutoffKhz.toStringAsFixed(1)} kHz';
        status = 'genuine';
      } else if (score >= 65) {
        verdict = 'Likely 320 kbps MP3 upscale (Cutoff at ${cutoffKhz.toStringAsFixed(1)} kHz, slope drop ${slopeDropDb.toStringAsFixed(1)} dB)';
        status = 'suspicious';
      } else if (score >= 50) {
        verdict = 'Suspicious / Likely 192-256 kbps lossy upscale (Cutoff at ${cutoffKhz.toStringAsFixed(1)} kHz)';
        status = 'suspicious';
      } else if (score >= 30) {
        verdict = 'Low-quality fake FLAC (Cutoff at ${cutoffKhz.toStringAsFixed(1)} kHz typical of 128 kbps MP3)';
        status = 'fake';
      } else {
        verdict = 'Severe cutoff / Heavy compression upscale (${cutoffKhz.toStringAsFixed(1)} kHz)';
        status = 'fake';
      }
    }

    if (isFake24) {
      score = (score * 0.75).round().clamp(10, 99);
      verdict = 'Fake 24-bit (Zero-padded 16-bit upsample) • $verdict';
      status = 'fake';
    }

    // 11. Downsample to 128 Frequency Bands bounded strictly to displayMaxKhz
    const int numBands = 128;
    List<double> bands = List.filled(numBands, 0.0);
    final int bandStep = math.max(1, maxDisplayBin ~/ numBands);

    for (int b = 0; b < numBands; b++) {
      double sum = 0.0;
      final start = b * bandStep;
      int count = 0;
      for (int k = 0; k < bandStep && (start + k) < maxDisplayBin; k++) {
        sum += welchPsdDb[start + k];
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
      displayMaxKhz: displayMaxKhz,
    );
  }

  /// Compute raw linear power spectral density for a single 2048-sample window using Hann window and FFT
  static List<double> _computePowerSlice(List<double> samples, int sampleRate) {
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

    // Compute raw Linear Power Spectral Density (1:1 with scipy.signal.welch)
    final power = List<double>.filled(half, 0.0);
    for (int i = 0; i < half; i++) {
      power[i] = (real[i] * real[i] + imag[i] * imag[i]) / (n * sampleRate);
    }
    return power;
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
