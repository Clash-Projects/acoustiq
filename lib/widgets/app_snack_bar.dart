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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x60121620) : const Color(0xB5FFFFFF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0x35FFFFFF) : const Color(0x18000000),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(isDark ? 0.22 : 0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 16, color: accent),
                  ),
                  const SizedBox(width: 12),
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

