import 'package:flutter_test/flutter_test.dart';
import 'package:flac_toolkit/services/app_update_service.dart';
import 'package:flac_toolkit/services/native_audio_service.dart';

void main() {
  group('AppUpdateService', () {
    test('uses Clash-Projects official Discord invite URL', () {
      expect(AppUpdateService.discordCommunityUrl, 'https://discord.gg/DmyM2p2fMe');
    });

    test('compares semantic versions accurately', () {
      expect(AppUpdateService.isNewerVersion('v1.2.0', '1.1.0'), isTrue);
      expect(AppUpdateService.isNewerVersion('1.1.1', '1.1.0'), isTrue);
      expect(AppUpdateService.isNewerVersion('v1.1.0', '1.1.0'), isFalse);
      expect(AppUpdateService.isNewerVersion('1.0.9', '1.1.0'), isFalse);
    });

    test('extracts build numbers and versions from nightly APK names', () {
      expect(AppUpdateService.extractApkBuildNumber('AcoustiQ-v1.1.0-build94.apk'), 94);
      expect(AppUpdateService.extractVersionCandidate('nightly', 'AcoustiQ-v1.1.0-build94.apk'), '1.1.0');
      expect(AppUpdateService.extractVersionCandidate('v1.2.0', null), '1.2.0');
    });

    test('picks newer prerelease nightly builds and skips drafts', () {
      final payload = [
        {
          'tag_name': 'v2.0.0',
          'draft': true,
          'assets': [],
        },
        {
          'tag_name': 'nightly',
          'draft': false,
          'name': 'AcoustiQ Nightly Build',
          'html_url': 'https://github.com/Clash-Projects/acoustiq/releases/tag/nightly',
          'assets': [
            {
              'name': 'AcoustiQ-v1.1.0-build95.apk',
              'browser_download_url': 'https://example.com/AcoustiQ-v1.1.0-build95.apk',
              'size': 74600000,
            }
          ],
        },
      ];

      final picked = AppUpdateService.pickNewerRelease(
        payload,
        currentVersion: '1.1.0',
        currentBuild: 89,
      );

      expect(picked, isNotNull);
      expect(picked!.tagName, 'nightly');
      expect(picked.version, '1.1.0');
      expect(picked.apkFileName, 'AcoustiQ-v1.1.0-build95.apk');

      final sameOrOlder = AppUpdateService.pickNewerRelease(
        payload,
        currentVersion: '1.1.0',
        currentBuild: 95,
      );
      expect(sameOrOlder, isNull);
    });
  });

  group('AudioSignalPath honesty defaults', () {
    test('defaults isBitPerfect to false until USB exclusive is active', () {
      const path = AudioSignalPath();
      expect(path.isBitPerfect, isFalse);
    });
  });
}
