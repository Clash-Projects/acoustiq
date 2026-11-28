import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../services/mock_flac_factory.dart';
import '../services/audio_playback_service.dart';
import '../ui/theme/colors.dart';
import 'glass_surface.dart';
import 'luminous_feedback.dart';
import 'app_glass_dialog.dart';
import 'app_snack_bar.dart';
import 'lyrics_viewer_sheet.dart';
import 'bounded_scroll_physics.dart';

/// Shows the AcoustiQ Developer Laboratory & QA Sandbox
void showDevLabSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const DevLabSheet(),
  );
}

class DevLabSheet extends StatelessWidget {
  const DevLabSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final textColor = appState.getTextColor(context);
        final subTextColor = appState.getSubTextColor(context);
        final activeAccent = appState.getAccentColor(context);
        final maxHeight = MediaQuery.of(context).size.height * 0.88;

        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: GlassSurface(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            style: GlassStyle.frosted,
            borderless: false,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x40FFFFFF) : const Color(0x35000000),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header Bar
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: activeAccent.withOpacity(isDark ? 0.22 : 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: activeAccent.withOpacity(0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          Icons.science_rounded,
                          size: 22,
                          color: activeAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'AcoustiQ Dev Lab',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.genuineEmerald.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'QA SUITE',
                                    style: TextStyle(
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.genuineEmerald,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Instant mock injection, theme matrix & contrast QA',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: subTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, size: 20, color: subTextColor),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Hairline Separator
                  Container(
                    height: 1,
                    color: isDark ? const Color(0x1AFFFFFF) : const Color(0x12000000),
                  ),

                  const SizedBox(height: 10),

                  // Scrollable QA Tools Body
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BoundedBouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Instant Track Injector
                          _buildSectionTitle('⚡ 1-Tap Mock Audio Injector', activeAccent),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _mockButton(
                                label: '✦ Genuine 96k Hi-Res',
                                icon: Icons.verified_rounded,
                                color: AppColors.genuineEmerald,
                                isDark: isDark,
                                isSelected: appState.injectedMockTrack?.status == 'genuine' &&
                                    appState.injectedMockTrack?.sampleRate == 96000,
                                onTap: () {
                                  appState.injectMockTrack(MockFlacFactory.createMockGenuineHiRes());
                                  _showLabFeedback(context, 'Injected: 96kHz 24-bit Genuine Hi-Res');
                                },
                              ),
                              _mockButton(
                                label: '⚠️ Fake MP3 Upsample',
                                icon: Icons.warning_amber_rounded,
                                color: AppColors.fakeCoral,
                                isDark: isDark,
                                isSelected: appState.injectedMockTrack?.status == 'fake',
                                onTap: () {
                                  appState.injectMockTrack(MockFlacFactory.createMockFakeUpsample());
                                  _showLabFeedback(context, 'Injected: 16kHz MP3 Upsample');
                                },
                              ),
                              _mockButton(
                                label: '📏 Long Overflow Title',
                                icon: Icons.text_fields_rounded,
                                color: AppColors.suspiciousAmber,
                                isDark: isDark,
                                isSelected: appState.injectedMockTrack?.title.length != null &&
                                    appState.injectedMockTrack!.title.length > 50,
                                onTap: () {
                                  appState.injectMockTrack(MockFlacFactory.createMockLongTitleOverflow());
                                  _showLabFeedback(context, 'Injected: 160-char Overflow Track');
                                },
                              ),
                              _mockButton(
                                label: '🎵 Full Synced LRC',
                                icon: Icons.lyrics_rounded,
                                color: const Color(0xFF38BDF8),
                                isDark: isDark,
                                isSelected: appState.injectedMockTrack?.fileName == 'Synced_Lyrics_Showcase.flac',
                                onTap: () {
                                  appState.injectMockTrack(MockFlacFactory.createMockSyncedLyricsTrack());
                                  _showLabFeedback(context, 'Injected: Full Synced Lyrics Track');
                                },
                              ),
                              if (appState.injectedMockTrack != null)
                                _mockButton(
                                  label: '✕ Clear Mock Track',
                                  icon: Icons.refresh_rounded,
                                  color: subTextColor,
                                  isDark: isDark,
                                  isSelected: false,
                                  onTap: () {
                                    appState.injectMockTrack(null);
                                    _showLabFeedback(context, 'Cleared Mock Track');
                                  },
                                ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // 2. In-Situ Live Theme & Accent Bar
                          _buildSectionTitle('🎨 In-Situ Live Theme & Accent Matrix', activeAccent),
                          Text(
                            'Switch themes in real-time without leaving this screen:',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: subTextColor),
                          ),
                          const SizedBox(height: 8),

                          // Theme mode
                          Row(
                            children: [
                              Expanded(child: _segmentPill('System', Icons.settings_brightness_rounded, appState.themeMode == 'system', isDark, activeAccent, () => appState.setThemeMode('system'))),
                              const SizedBox(width: 6),
                              Expanded(child: _segmentPill('Light', Icons.light_mode_rounded, appState.themeMode == 'light', isDark, activeAccent, () => appState.setThemeMode('light'))),
                              const SizedBox(width: 6),
                              Expanded(child: _segmentPill('Dark', Icons.dark_mode_rounded, appState.themeMode == 'dark', isDark, activeAccent, () => appState.setThemeMode('dark'))),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Accents Grid
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _accentChip('Mono', Colors.white, appState.accentPreset == 'Monochrome' || appState.accentPreset == 'Titanium Mono' || appState.accentPreset == 'Mono', isDark, () => appState.setAccentPreset('Monochrome')),
                              _accentChip('Cyan', const Color(0xFF00E5FF), appState.accentPreset == 'Cyan' || appState.accentPreset == 'Prism Cyan' || appState.accentPreset == 'Ocean', isDark, () => appState.setAccentPreset('Cyan')),
                              _accentChip('Amber', const Color(0xFFFF9500), appState.accentPreset == 'Amber' || appState.accentPreset == 'Analog Amber', isDark, () => appState.setAccentPreset('Amber')),
                              _accentChip('Emerald', const Color(0xFF00E676), appState.accentPreset == 'Emerald' || appState.accentPreset == 'Acoustic Emerald' || appState.accentPreset == 'Sage', isDark, () => appState.setAccentPreset('Emerald')),
                              _accentChip('Violet', const Color(0xFF8B5CF6), appState.accentPreset == 'Violet' || appState.accentPreset == 'Ultraviolet Hi-Res', isDark, () => appState.setAccentPreset('Violet')),
                              _accentChip('Crimson', const Color(0xFFFF3B30), appState.accentPreset == 'Crimson' || appState.accentPreset == 'Crimson Peak', isDark, () => appState.setAccentPreset('Crimson')),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Quick Toggle Switches
                          Row(
                            children: [
                              Expanded(
                                child: _togglePill(
                                  label: 'Liquid Glass',
                                  value: appState.isLiquidGlass,
                                  isDark: isDark,
                                  activeAccent: activeAccent,
                                  onChanged: (val) => appState.setLiquidGlass(val),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _togglePill(
                                  label: 'AMOLED Pitch',
                                  value: appState.amoledMode,
                                  isDark: isDark,
                                  activeAccent: activeAccent,
                                  onChanged: (val) => appState.setAmoledMode(val),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _togglePill(
                                  label: '⚡ Strict Low-Power',
                                  value: appState.strictLowPowerMode,
                                  isDark: isDark,
                                  activeAccent: activeAccent,
                                  onChanged: (val) {
                                    appState.setStrictLowPowerMode(val);
                                    _showLabFeedback(context, val ? '⚡ Low-Power Active (Zero Blur 60FPS)' : '✨ Normal Rendering');
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _togglePill(
                                  label: '📱 Auto Tiering',
                                  value: appState.autoHardwareTiering,
                                  isDark: isDark,
                                  activeAccent: activeAccent,
                                  onChanged: (val) {
                                    appState.setAutoHardwareTiering(val);
                                    _showLabFeedback(context, val ? '📱 Auto Hardware Tiering ON' : '⚙️ Manual Hardware Tiering');
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Typography Engine (All 4 Designer Fonts)
                          _buildSectionTitle('🔤 Typography Engine (Instant Live Switch)', activeAccent),
                          Text(
                            'Compare all 4 studio fonts live across the entire interface:',
                            style: TextStyle(fontSize: 11.5, color: subTextColor),
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: _fontSegmentPill(
                                  label: '🍏 SF Pro',
                                  subLabel: 'Apple visionOS',
                                  fontKey: 'SF-Pro',
                                  isSelected: appState.fontFamily == 'SF-Pro',
                                  isDark: isDark,
                                  activeAccent: activeAccent,
                                  onTap: () {
                                    appState.setFontFamily('SF-Pro');
                                    _showLabFeedback(context, 'Active Font: SF Pro (Apple visionOS)');
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _fontSegmentPill(
                                  label: '⚡ Geist',
                                  subLabel: 'Vercel / Linear',
                                  fontKey: 'Geist',
                                  isSelected: appState.fontFamily == 'Geist',
                                  isDark: isDark,
                                  activeAccent: activeAccent,
                                  onTap: () {
                                    appState.setFontFamily('Geist');
                                    _showLabFeedback(context, 'Active Font: Geist Sans (Vercel)');
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _fontSegmentPill(
                                  label: '🌊 Jakarta',
                                  subLabel: 'Geometric Tech',
                                  fontKey: 'PlusJakartaSans',
                                  isSelected: appState.fontFamily == 'PlusJakartaSans',
                                  isDark: isDark,
                                  activeAccent: activeAccent,
                                  onTap: () {
                                    appState.setFontFamily('PlusJakartaSans');
                                    _showLabFeedback(context, 'Active Font: Plus Jakarta Sans');
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _fontSegmentPill(
                                  label: '🎛️ Inter',
                                  subLabel: 'Tuned Sleek',
                                  fontKey: 'Inter',
                                  isSelected: appState.fontFamily == 'Inter',
                                  isDark: isDark,
                                  activeAccent: activeAccent,
                                  onTap: () {
                                    appState.setFontFamily('Inter');
                                    _showLabFeedback(context, 'Active Font: Inter');
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // 3. Modal & Toast Trigger Matrix
                          _buildSectionTitle('🪟 Instant Modal & Contrast QA', activeAccent),
                          Text(
                            'Test blur, contrast, and white-on-white text in 1-tap:',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: subTextColor),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _actionPill(
                                label: 'Test Glass Dialog',
                                icon: Icons.chat_bubble_outline_rounded,
                                isDark: isDark,
                                textColor: textColor,
                                onTap: () {
                                  showAppGlassDialog(
                                    context: context,
                                    title: 'QA Glass Dialog Contrast',
                                    content: 'Verifying that button text is completely readable in Monochrome and colorful modes with zero white-on-white bleed.',
                                    confirmLabel: 'Looks Perfect',
                                    cancelLabel: 'Dismiss',
                                    icon: Icons.check_circle_outline_rounded,
                                    iconColor: activeAccent,
                                  );
                                },
                              ),
                              _actionPill(
                                label: 'Test Glass Toast',
                                icon: Icons.notifications_active_outlined,
                                isDark: isDark,
                                textColor: textColor,
                                onTap: () {
                                  showThemedSnackBar(
                                    context,
                                    'AcoustiQ Frosted Glass Toast Notification active!',
                                    icon: Icons.auto_awesome_rounded,
                                  );
                                },
                              ),
                              _actionPill(
                                label: 'Open Lyrics Sheet',
                                icon: Icons.lyrics_outlined,
                                isDark: isDark,
                                textColor: textColor,
                                onTap: () {
                                  final track = appState.injectedMockTrack ??
                                      MockFlacFactory.createMockSyncedLyricsTrack();
                                  showLyricsViewerSheet(context, track);
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // 4. Audio Playback Position Simulator
                          _buildSectionTitle('⏱️ Audio Seek Simulator (Lyrics Scroll QA)', activeAccent),
                          Text(
                            'Simulate playback timestamps to test lyrics auto-scrolling speed:',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: subTextColor),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _seekChip('0:00', 0, isDark, activeAccent),
                              const SizedBox(width: 6),
                              _seekChip('0:10', 10000, isDark, activeAccent),
                              const SizedBox(width: 6),
                              _seekChip('0:30', 30000, isDark, activeAccent),
                              const SizedBox(width: 6),
                              _seekChip('0:50', 50000, isDark, activeAccent),
                              const SizedBox(width: 6),
                              _seekChip('1:15', 75000, isDark, activeAccent),
                            ],
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLabFeedback(BuildContext context, String msg) {
    if (appState.hapticsEnabled) HapticFeedback.selectionClick();
    showThemedSnackBar(context, '🧪 $msg', icon: Icons.science_rounded);
  }

  Widget _buildSectionTitle(String title, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: accent,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _mockButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return LuminousFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(isDark ? 0.35 : 0.22)
              : (isDark ? const Color(0x20FFFFFF) : const Color(0x10000000)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0x22FFFFFF) : const Color(0x14000000)),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? color : (isDark ? Colors.white : const Color(0xFF101828)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmentPill(String label, IconData icon, bool isSelected, bool isDark, Color activeAccent, VoidCallback onTap) {
    return LuminousFeedback(
      onTap: () {
        if (appState.hapticsEnabled) HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? activeAccent.withOpacity(isDark ? 0.35 : 0.22)
              : (isDark ? const Color(0x1CFFFFFF) : const Color(0x0C000000)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeAccent : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? activeAccent : (isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeAccent : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accentChip(String name, Color color, bool isSelected, bool isDark, VoidCallback onTap) {
    return LuminousFeedback(
      onTap: () {
        if (appState.hapticsEnabled) HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.3) : (isDark ? const Color(0x18FFFFFF) : const Color(0x0A000000)),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _togglePill({
    required String label,
    required bool value,
    required bool isDark,
    required Color activeAccent,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x1CFFFFFF) : const Color(0x0C000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Switch(
            value: value,
            activeColor: activeAccent,
            onChanged: (v) {
              if (appState.hapticsEnabled) HapticFeedback.selectionClick();
              onChanged(v);
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _actionPill({
    required String label,
    required IconData icon,
    required bool isDark,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return LuminousFeedback(
      onTap: () {
        if (appState.hapticsEnabled) HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x22FFFFFF) : const Color(0x10000000),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0x22FFFFFF) : const Color(0x14000000),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: textColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seekChip(String label, int ms, bool isDark, Color activeAccent) {
    return Expanded(
      child: LuminousFeedback(
        onTap: () {
          if (appState.hapticsEnabled) HapticFeedback.selectionClick();
          AudioPlaybackService.instance.seek(ms);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: activeAccent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _fontSegmentPill({
    required String label,
    required String subLabel,
    required String fontKey,
    required bool isSelected,
    required bool isDark,
    required Color activeAccent,
    required VoidCallback onTap,
  }) {
    return LuminousFeedback(
      onTap: () {
        if (appState.hapticsEnabled) HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeAccent.withOpacity(isDark ? 0.28 : 0.18)
              : (isDark ? const Color(0x14FFFFFF) : const Color(0x0C000000)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? activeAccent
                : (isDark ? const Color(0x22FFFFFF) : const Color(0x15000000)),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: fontKey,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? activeAccent : (isDark ? Colors.white : Colors.black87),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 14, color: activeAccent),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subLabel,
              style: TextStyle(
                fontFamily: fontKey,
                fontSize: 10,
                color: isSelected
                    ? activeAccent.withOpacity(0.85)
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
