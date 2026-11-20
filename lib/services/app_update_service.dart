import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  updateAvailable,
  error,
}

class UpdateInfo {
  final String version;
  final String tagName;
  final String title;
  final String notes;
  final String releaseUrl;
  final String? apkDownloadUrl;
  final String? apkFileName;
  final int? apkSizeBytes;
  final DateTime? publishedAt;

  const UpdateInfo({
    required this.version,
    required this.tagName,
    required this.title,
    required this.notes,
    required this.releaseUrl,
    this.apkDownloadUrl,
    this.apkFileName,
    this.apkSizeBytes,
    this.publishedAt,
  });

  String get formattedSize {
    if (apkSizeBytes == null || apkSizeBytes! <= 0) return '';
    final mb = apkSizeBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UpdateCheckResult {
  final UpdateStatus status;
  final UpdateInfo? updateInfo;
  final String message;

  const UpdateCheckResult({
    required this.status,
    this.updateInfo,
    required this.message,
  });
}

class AppUpdateService extends ChangeNotifier {
  static final AppUpdateService instance = AppUpdateService._();
  AppUpdateService._();

  // Application Telemetry
  static const String currentVersion = '1.0.0';
  static const int currentBuild = 88;
  static const String repoOwner = 'NONDEADER';
  static const String repoName = 'acoustiq';
  static const String githubRepoUrl = 'https://github.com/NONDEADER/acoustiq';
  static const String developerProfileUrl = 'https://github.com/NONDEADER';
  static const String issuesUrl = 'https://github.com/NONDEADER/acoustiq/issues';

  static const String _apiEndpoint =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  UpdateStatus _status = UpdateStatus.idle;
  UpdateInfo? _latestUpdate;
  String _lastErrorMessage = '';
  DateTime? _lastCheckedAt;

  UpdateStatus get status => _status;
  UpdateInfo? get latestUpdate => _latestUpdate;
  String get lastErrorMessage => _lastErrorMessage;
  DateTime? get lastCheckedAt => _lastCheckedAt;
  bool get isChecking => _status == UpdateStatus.checking;
  bool get hasUpdate => _status == UpdateStatus.updateAvailable && _latestUpdate != null;

  /// Compares semantic version strings (e.g., '1.0.1' > '1.0.0').
  static bool isNewerVersion(String remote, String current) {
    try {
      final cleanRemote = remote.trim().toLowerCase().replaceAll(RegExp(r'^v'), '');
      final cleanCurrent = current.trim().toLowerCase().replaceAll(RegExp(r'^v'), '');

      final rParts = cleanRemote.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
      final cParts = cleanCurrent.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();

      final maxLen = rParts.length > cParts.length ? rParts.length : cParts.length;
      while (rParts.length < maxLen) {
        rParts.add(0);
      }
      while (cParts.length < maxLen) {
        cParts.add(0);
      }

      for (int i = 0; i < maxLen; i++) {
        if (rParts[i] > cParts[i]) return true;
        if (rParts[i] < cParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Queries GitHub Releases API for latest public release
  Future<UpdateCheckResult> checkForUpdates() async {
    if (_status == UpdateStatus.checking) {
      return UpdateCheckResult(
        status: _status,
        updateInfo: _latestUpdate,
        message: 'Update check already in progress...',
      );
    }

    _status = UpdateStatus.checking;
    _lastErrorMessage = '';
    notifyListeners();

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      final request = await client.getUrl(Uri.parse(_apiEndpoint));
      request.headers.set('User-Agent', 'AcoustiQ-Mobile/$currentVersion');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      _lastCheckedAt = DateTime.now();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final tagName = (data['tag_name'] as String?) ?? '';
        final cleanVersion = tagName.replaceAll(RegExp(r'^v'), '');
        final releaseTitle = (data['name'] as String?) ?? 'AcoustiQ $tagName';
        final releaseUrl = (data['html_url'] as String?) ?? githubRepoUrl;
        final notes = (data['body'] as String?) ?? 'No release notes provided.';
        final publishedStr = data['published_at'] as String?;
        final publishedAt = publishedStr != null ? DateTime.tryParse(publishedStr) : null;

        // Find APK asset
        String? apkUrl;
        String? apkName;
        int? apkSize;
        final assets = data['assets'] as List<dynamic>?;
        if (assets != null) {
          for (final asset in assets) {
            if (asset is Map<String, dynamic>) {
              final name = (asset['name'] as String?) ?? '';
              if (name.toLowerCase().endsWith('.apk')) {
                apkUrl = asset['browser_download_url'] as String?;
                apkName = name;
                apkSize = asset['size'] as int?;
                break;
              }
            }
          }
        }

        final update = UpdateInfo(
          version: cleanVersion,
          tagName: tagName,
          title: releaseTitle,
          notes: notes,
          releaseUrl: releaseUrl,
          apkDownloadUrl: apkUrl,
          apkFileName: apkName,
          apkSizeBytes: apkSize,
          publishedAt: publishedAt,
        );

        if (isNewerVersion(cleanVersion, currentVersion)) {
          _latestUpdate = update;
          _status = UpdateStatus.updateAvailable;
          notifyListeners();
          return UpdateCheckResult(
            status: _status,
            updateInfo: update,
            message: 'New version available: $tagName',
          );
        } else {
          _latestUpdate = null;
          _status = UpdateStatus.upToDate;
          notifyListeners();
          return UpdateCheckResult(
            status: _status,
            message: 'AcoustiQ is up to date (v$currentVersion)',
          );
        }
      } else if (response.statusCode == 404) {
        // Repository has no public releases published yet
        _status = UpdateStatus.upToDate;
        notifyListeners();
        return UpdateCheckResult(
          status: _status,
          message: 'AcoustiQ is on the latest build (v$currentVersion)',
        );
      } else {
        _status = UpdateStatus.error;
        _lastErrorMessage = 'Server returned HTTP ${response.statusCode}';
        notifyListeners();
        return UpdateCheckResult(
          status: _status,
          message: 'Unable to check for updates (HTTP ${response.statusCode})',
        );
      }
    } catch (e) {
      _status = UpdateStatus.error;
      _lastErrorMessage = e.toString();
      notifyListeners();
      return UpdateCheckResult(
        status: _status,
        message: 'Could not connect to GitHub. Check your network.',
      );
    } finally {
      client.close();
    }
  }
}
