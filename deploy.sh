#!/bin/bash
# AcoustiQ 1-Click Fast Local Deploy
# Builds release APK locally and installs to connected wireless/USB device via ADB

set -e

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

echo "=========================================="
echo "⚡ AcoustiQ 1-Click Local Deploy"
echo "=========================================="

# Check if ADB sees any device
DEVICE_COUNT=$(adb devices | grep -v "List" | grep "device" | wc -l)
if [ "$DEVICE_COUNT" -eq 0 ]; then
  echo "⚠️ No ADB device found!"
  echo "Please connect via USB or run: adb connect <DEVICE_IP>:5555"
  exit 1
fi

echo "📱 Target device found:"
adb devices | grep "device$"

echo ""
echo "📦 Step 1/3: Building release APK locally..."
flutter build apk --release

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK_PATH" ]; then
  echo "❌ Error: APK not found at $APK_PATH"
  exit 1
fi

echo ""
echo "🚀 Step 2/3: Installing APK to device via ADB..."
adb install -r "$APK_PATH"

echo ""
echo "▶️ Step 3/3: Launching AcoustiQ on device..."
adb shell am start -n com.example.flac_toolkit/com.example.flac_toolkit.MainActivity

echo ""
echo "=========================================="
echo "🎉 Deployed successfully in seconds!"
echo "Zero cloud wait • Zero quota used"
echo "=========================================="
