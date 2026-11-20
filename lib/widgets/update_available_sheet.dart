import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../services/app_update_service.dart';
import '../services/app_url_launcher.dart';
import '../ui/theme/colors.dart';
import 'glass_surface.dart';
import 'luminous_feedback.dart';

/// Displays the WWDC25 Frosted Glass Update Sheet
void showUpdateAvailableSheet(BuildContext context, UpdateInfo update) {
  if (appState.hapticsEnabled) {
    HapticFeedback.mediumImpact();
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => UpdateAvailableSheet(update: update),
  );
}

class UpdateAvailableSheet extends StatelessWidget {
  final UpdateInfo update;

  const UpdateAvailableSheet({super.key, required this.update});

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isCurrentDark(context);
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final subTextColor = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSecondary;
    final accent = appState.getAccentColor(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      decoration: BoxDecoration(
        color: isDark
            ? (appState.amoledMode ? const Color(0xFF0A0C0E) : const Color(0xFF14171C))
            : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? const Color(0x33FFFFFF) : const Color(0x18000000),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0x40FFFFFF) : const Color(0x28000000),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withOpacity(0.3),
                        accent.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accent.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.rocket_launch_rounded,
                    color: accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Update Available',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              update.tagName,
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'v${AppUpdateService.currentVersion}  →  ${update.tagName}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: subTextColor,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.6),

          // Release Details & Scrollable Notes
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x18FFFFFF) : const Color(0x0A000000),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0x1FFFFFFF) : const Color(0x10000000),
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          update.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        if (update.formattedSize.isNotEmpty || update.publishedAt != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (update.formattedSize.isNotEmpty) ...[
                                Icon(Icons.download_rounded, size: 14, color: subTextColor),
                                const SizedBox(width: 4),
                                Text(
                                  update.formattedSize,
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 11,
                                    color: subTextColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              if (update.publishedAt != null) ...[
                                Icon(Icons.calendar_today_rounded, size: 13, color: subTextColor),
                                const SizedBox(width: 4),
                                Text(
                                  '${update.publishedAt!.day}/${update.publishedAt!.month}/${update.publishedAt!.year}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: subTextColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // What's New Header
                  Text(
                    "WHAT'S NEW",
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Notes Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x10FFFFFF) : const Color(0x06000000),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0x12FFFFFF) : const Color(0x0A000000),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      update.notes,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: textColor.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, thickness: 0.6),

          // Actions Dock
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              children: [
                if (update.apkDownloadUrl != null) ...[
                  LuminousFeedback(
                    onTap: () {
                      if (appState.hapticsEnabled) HapticFeedback.mediumImpact();
                      AppUrlLauncher.openUrl(context, update.apkDownloadUrl!);
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: GlassSurface(
                      style: GlassStyle.frosted,
                      borderRadius: BorderRadius.circular(16),
                      tintColor: accent.withOpacity(0.25),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download_rounded, color: accent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Download APK ${update.formattedSize.isNotEmpty ? "(${update.formattedSize})" : ""}',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                Row(
                  children: [
                    Expanded(
                      child: LuminousFeedback(
                        onTap: () {
                          if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                          AppUrlLauncher.openUrl(context, update.releaseUrl);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0x25FFFFFF) : const Color(0x18000000),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.open_in_new_rounded, size: 16, color: textColor),
                              const SizedBox(width: 6),
                              Text(
                                'View on GitHub',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    LuminousFeedback(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Later',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: subTextColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
