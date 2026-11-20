import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_snack_bar.dart';

class AppUrlLauncher {
  static const MethodChannel _channel = MethodChannel('flac_toolkit/audio_decoder');

  /// Launches an external URL via native Android Intent.
  /// Falls back to copying to clipboard if no browser or activity can handle it.
  static Future<bool> openUrl(BuildContext context, String url) async {
    try {
      final success = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      if (success == true) return true;
    } catch (_) {
      // ActivityNotFound or Intent failure
    }

    // Fallback: Copy to clipboard and inform user
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        showThemedSnackBar(
          context,
          'Link copied to clipboard: $url',
          icon: Icons.copy_rounded,
        );
      }
    } catch (_) {}

    return false;
  }
}
