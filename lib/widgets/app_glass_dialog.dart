import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';
import 'glass_surface.dart';
import 'luminous_feedback.dart';

/// Apple WWDC25 Frosted Glass Dialog & Alert Controller
///
/// Features:
/// 1. Optical Backdrop Blur (sigma: 28) with deep obsidian glass canvas (zero background bleed).
/// 2. Specular 0.8dp hairline rim with continuous 24dp curvature.
/// 3. High-contrast typography matching iOS 18 Design Language.
/// 4. Flexible action bar: single "Got it" pill or dual [ Cancel | Action ] segmented glass buttons.
Future<T?> showAppGlassDialog<T>({
  required BuildContext context,
  required String title,
  required String content,
  IconData? icon,
  Color? iconColor,
  String confirmLabel = 'Got it',
  VoidCallback? onConfirm,
  String? cancelLabel,
  VoidCallback? onCancel,
  bool isDestructive = false,
  Widget? customBody,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (ctx) {
      final isDark = appState.isCurrentDark(ctx);
      final textColor = appState.getTextColor(ctx);
      final subTextColor = appState.getSubTextColor(ctx);
      final activeAccent = appState.getAccentColor(ctx);
      final onAccentColor = isDestructive
          ? Colors.white
          : AppColors.getOnAccentColor(activeAccent, isDark: isDark);

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x75121620) : const Color(0xAAFFFFFF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0x35FFFFFF) : const Color(0x20000000),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.45 : 0.15),
                    blurRadius: 32,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: Icon + Title
                Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (iconColor ?? activeAccent).withOpacity(isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: iconColor ?? activeAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Content
                if (customBody != null)
                  customBody
                else
                  Text(
                    content,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      height: 1.45,
                      color: subTextColor,
                    ),
                  ),

                const SizedBox(height: 20),

                // Action Bar
                if (cancelLabel != null) ...[
                  Row(
                    children: [
                      // Cancel Button
                      Expanded(
                        child: LuminousFeedback(
                          onTap: () {
                            if (appState.hapticsEnabled) HapticFeedback.lightImpact();
                            Navigator.of(ctx).pop();
                            onCancel?.call();
                          },
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0x18FFFFFF) : const Color(0x0F000000),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              cancelLabel,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: subTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Confirm Button
                      Expanded(
                        child: LuminousFeedback(
                          onTap: () {
                            if (appState.hapticsEnabled) HapticFeedback.mediumImpact();
                            Navigator.of(ctx).pop(true);
                            onConfirm?.call();
                          },
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDestructive
                                  ? AppColors.fakeCoral.withOpacity(0.9)
                                  : activeAccent,
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDestructive ? AppColors.fakeCoral : activeAccent)
                                      .withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              confirmLabel,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: onAccentColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Single Confirm Pill
                  LuminousFeedback(
                    onTap: () {
                      if (appState.hapticsEnabled) HapticFeedback.lightImpact();
                      Navigator.of(ctx).pop(true);
                      onConfirm?.call();
                    },
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: activeAccent,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: activeAccent.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        confirmLabel,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: onAccentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  },
);
}

