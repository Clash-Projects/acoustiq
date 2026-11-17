# AcoustiQ 🎵 High-Res Audio Toolkit & Integrity Engine

[![Flutter](https://img.shields.io/badge/Flutter-3.50.0-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.14.0-0175C2?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Platform-Android%20API%2021--36-3DDC84?logo=android)](https://developer.android.com)
[![Gradle](https://img.shields.io/badge/Gradle-9.3.1-02303A?logo=gradle)](https://gradle.org)
[![Kotlin](https://img.shields.io/badge/Kotlin-2.2.20-7F52FF?logo=kotlin)](https://kotlinlang.org)

**AcoustiQ** is a high-performance, studio-grade lossless FLAC inspection, audio integrity verification, and library intelligence suite engineered for Android devices. Featuring a custom **120 FPS Sub-Stepped Euler Physics Liquid Glass Navigation Dock**, hardware-accelerated MediaCodec decoding, and bit-for-bit MD5 audio stream verification.

---

## 🌟 Core Features

### 1. 🔍 Acoustic Spectrum & Lossless Audio Inspector
* **Hardware-Accelerated Decoding:** Uses native Android `MediaCodec` and `MediaExtractor` pipelines for zero-latency PCM sample analysis.
* **Fake FLAC & Cutoff Detection:** Accurately differentiates authentic studio masters from low-bitrate MP3s re-encoded into FLAC containers using high-frequency cutoff roll-off analysis (16 kHz, 19 kHz, 20.5 kHz, 22+ kHz).
* **Detailed Bitstream Telemetry:** Displays true sampling rates (44.1 kHz to 192 kHz), bit depths (16-bit, 24-bit studio, 32-bit float), audio channels, and bitrate.

### 2. 🛡️ Audio Integrity & Studio Hash Verification
* **Bit-Rot & Corruption Detection:** Verifies raw decoded PCM audio samples against the unalterable 128-bit MD5 checksum embedded in the FLAC stream metadata block during studio mastering.
* **Bit-Perfect Guarantee:** Alerts users immediately if storage degradation, incomplete transfers, or SD card sector faults flip any audio bits.
* **Lossless Extraction Tools:** One-tap lossless export of embedded full-resolution cover art and synchronized `.LRC` lyrics files directly to device storage.

### 3. 💧 Liquid Lens Navigation Dock (Phase 12 Architecture)
* **Sub-Stepped Semi-Implicit Euler Engine:** Evaluated at 240 Hz sub-stepping inside Flutter `Ticker` (`stiffness: 280`, `damping: 31.4`) delivering true 120 FPS inertial physics.
* **Kinematic Squash & Stretch:** Velocity-vector deformation proportional to movement acceleration ($\frac{d^2x}{dt^2}$).
* **Concentric Island Geometry (319dp $\times$ 62dp):** Shared-arc geometry, frosted glass optical blur, and directional illumination without chromatic fringes.

### 4. ⚡ Synchronized Storage & Cache Management
* **Native Kernel Sync:** Direct integration with Android OS `StorageStatsManager.queryStatsForPackage()` to reflect exact storage footprint down to the byte.
* **Interactive Refresh:** One-tap manual refresh button (`[ 🔄 ]`) with animated spin and haptic feedback.
* **Full Library Pruning:** Safe atomic purging of decoded PCM chunks, memory caches, and image buffers.

---

## 📂 Project Architecture

```
mobile_app/
├── android/                   # Gradle 9.3.1 + AGP 9.1.1 + Kotlin 2.2.20 configuration
│   ├── app/src/main/kotlin/   # Native MainActivity.kt (Audio decoder & StorageStatsManager)
│   └── build.gradle           # Root build with subprojects compileSdk 36 enforcement
├── assets/                    # TrueType fonts (Inter, JetBrainsMono) & Curated wallpapers
├── lib/
│   ├── main.dart              # App bootstrap & global scroll behavior
│   ├── models/                # AppSettings, FlacInfo data models
│   ├── screens/
│   │   ├── inspect_screen.dart    # Telemetry, spectrum & integrity verification
│   │   ├── audit_screen.dart      # Library-wide batch quality scanner
│   │   ├── duplicates_screen.dart # Smart duplicate resolver & comparison engine
│   │   ├── settings_screen.dart   # Appearance, audio engine & cache maintenance
│   │   └── splash_screen.dart     # Atmospheric launch branding
│   ├── services/
│   │   ├── flac_parser.dart           # FLAC metadata & vorbis tag parser
│   │   ├── audio_dsp.dart             # High-frequency FFT & roll-off analyzer
│   │   ├── audio_playback_service.dart# Android MediaPlayer bridge
│   │   └── duplicate_detector.dart    # Multi-vector duplicate identification
│   └── widgets/
│       ├── liquid_lens_dock.dart      # 120 FPS Euler physics navigation dock
│       ├── audio_spectrum_stage.dart  # Interactive visualizer stage
│       ├── dev_lab_sheet.dart         # QA simulation & mock track injector
│       └── glass_card.dart            # Frosted glass UI surfaces
└── deploy.sh                  # 1-Click fast local build & wireless ADB deploy script
```

---

## ⚡ Fast Local Development & Deployment

AcoustiQ utilizes a local PC toolchain for **17-second incremental release builds** deployed wirelessly over ADB.

### Prerequisites
* Flutter 3.50.0+ (Dart 3.14.0+)
* Android SDK 36 (Build-Tools 36.0.0, Platform 36, NDK 28.2.13676358)
* OpenJDK 17

### 1-Click Wireless ADB Deploy (Recommended)
Connect your Android device over Wi-Fi:
```bash
adb connect <DEVICE_IP>:5555
./deploy.sh
```
`deploy.sh` automatically compiles the release APK locally, installs via ADB stream, and boots AcoustiQ on your device in **~17 to 20 seconds**.

### Live Screen Mirroring (scrcpy)
To mirror and control the connected device on your Linux desktop:
```bash
scrcpy -s <DEVICE_IP>:5555
```

---

## 📄 License
This project is licensed under the MIT License.
