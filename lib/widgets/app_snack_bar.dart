import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';

/// Shows an authentic Apple WWDC25 Frosted Glass floating toast notification
/// positioned cleanly above the liquid lens navigation dock.
void showThemedSnackBar(
  BuildContext context,
  String message, {
  IconData? icon,
  Color? accentColor,
  Duration duration = const Duration(seconds: 2),
}) {
  final isDark = appState.isCurrentDark(context);
  final textColor = isDark ? Colors.white : const Color(0xFF101828);
  final accent = accentColor ?? appState.getAccentColor(context);

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xE6141820) : const Color(0xF2FFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0x33FFFFFF) : const Color(0x20000000),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.40 : 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
