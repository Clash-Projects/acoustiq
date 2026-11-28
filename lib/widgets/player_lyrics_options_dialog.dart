import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../ui/theme/colors.dart';
import '../utils/lyrics_parser.dart';
import 'app_snack_bar.dart';
import 'glass_surface.dart';
import 'luminous_feedback.dart';

/// Hybrid AcoustiQ Lyrics Options Dialog with 3-tier WWDC25 Glass Hierarchy:
/// - Frosted base dialog container (20dp blur)
/// - Clear crystal glass for secondary actions, tags, & unselected chips (10dp blur)
/// - Liquid refraction glass for active toggle states & primary Done button (24dp blur)
Future<void> showPlayerLyricsOptionsDialog(
  BuildContext context, {
  required FlacInfo? track,
  required ParsedLyricsResult parsed,
}) {
  final hasGlass = appState.isLiquidGlass;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: hasGlass
        ? Colors.black.withOpacity(0.38)
        : Colors.black.withOpacity(0.62),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) => _HybridLyricsOptionsDialog(
      track: track,
      parsed: parsed,
    ),
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
      final content = FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
      if (!hasGlass) return content;
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 8.0 * curved.value,
          sigmaY: 8.0 * curved.value,
        ),
        child: content,
      );
    },
  );
}

class _HybridLyricsOptionsDialog extends StatefulWidget {
  final FlacInfo? track;
  final ParsedLyricsResult parsed;

  const _HybridLyricsOptionsDialog({
    required this.track,
    required this.parsed,
  });

  @override
  State<_HybridLyricsOptionsDialog> createState() =>
      _HybridLyricsOptionsDialogState();
}

class _HybridLyricsOptionsDialogState extends State<_HybridLyricsOptionsDialog> {
  static const MethodChannel _channel =
      MethodChannel('flac_toolkit/audio_decoder');

  late double _fontScale;
  late bool _centered;
  late String _style;
  late int _offsetMs;

  @override
  void initState() {
    super.initState();
    _fontScale = appState.lyricsFontScale;
    _centered = appState.lyricsCentered;
    _style = appState.lyricsStyle;
    _offsetMs = appState.lyricsOffsetMs;
  }

  Future<void> _exportLrc() async {
    final text = widget.parsed.rawExportText.trim();
    if (text.isEmpty) return;
    final track = widget.track;
    final fileName = (track?.title.isNotEmpty == true)
        ? track!.title
        : (track?.fileName ?? 'AcoustiQ_Lyrics');

    try {
      final res = await _channel.invokeMethod<Map>('exportLyrics', {
        'lyrics': text,
        'fileName': fileName,
      });
      if (!mounted) return;
      final savedPath = res?['path']?.toString() ?? '';
      Navigator.of(context).pop();
      showThemedSnackBar(
        context,
        savedPath.isNotEmpty
            ? 'Exported: ${savedPath.split('/').last}'
            : 'Lyrics saved to Downloads',
        icon: Icons.download_done_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      showThemedSnackBar(
        context,
        'Export failed: $e',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  void _copyLyrics() {
    final text = widget.parsed.rawExportText.trim();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    Navigator.of(context).pop();
    showThemedSnackBar(
      context,
      'Lyrics copied to clipboard',
      icon: Icons.copy_rounded,
    );
  }

  String _styleDescription(String style) {
    switch (style) {
      case 'flow':
        return 'Glowing lead sweep with soft blur on sung lines';
      case 'halo':
        return 'Spotlight focus with deep peripheral blur';
      case 'default':
      default:
        return 'Clean crisp contrast tuned for instant readability';
    }
  }

  String _sourceTag() {
    if (widget.parsed.sourceLabel.contains('.lrc')) return 'LOCAL .LRC';
    return 'EMBEDDED VORBIS';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);
    final activeAccent = appState.getAccentColor(context);
    final hasLyrics =
        widget.parsed.hasLyrics && widget.parsed.rawExportText.trim().isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(28),
            style: GlassStyle.frosted,
            borderless: false,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header: Liquid Squircle Badge + Title + Embedded Tag Pill + Clear Close Circle
                  Row(
                    children: [
                      GlassSurface(
                        borderRadius: BorderRadius.circular(11),
                        style: GlassStyle.liquid,
                        borderless: false,
                        tintColor: activeAccent.withOpacity(isDark ? 0.22 : 0.14),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.lyrics_rounded,
                            size: 18,
                            color: activeAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lyrics Options',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Embedded Vorbis / Local .LRC Tag Pill (Zero 'Offline' clutter)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GlassSurface(
                                borderRadius: BorderRadius.circular(8),
                                style: GlassStyle.clear,
                                borderless: false,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                child: Text(
                                  _sourceTag(),
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: subTextColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      LuminousFeedback(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(16),
                        child: GlassSurface(
                          borderRadius: BorderRadius.circular(16),
                          style: GlassStyle.clear,
                          borderless: false,
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(
                              Icons.close_rounded,
                              size: 17,
                              color: subTextColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (hasLyrics) ...[
                    const SizedBox(height: 15),
                    // Clear Glass Quick Action Tiles (Copy & Export .lrc)
                    Row(
                      children: [
                        Expanded(
                          child: _ClearGlassActionTile(
                            icon: Icons.copy_rounded,
                            label: 'Copy',
                            textColor: textColor,
                            onTap: () {
                              if (appState.hapticsEnabled) {
                                HapticFeedback.selectionClick();
                              }
                              _copyLyrics();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ClearGlassActionTile(
                            icon: Icons.download_rounded,
                            label: 'Export .lrc',
                            textColor: textColor,
                            onTap: () {
                              if (appState.hapticsEnabled) {
                                HapticFeedback.selectionClick();
                              }
                              _exportLrc();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Text Size Continuous Slider (Zero Tick Dots)
                  Row(
                    children: [
                      Text(
                        'Text size',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(_fontScale * 100).round()}%',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: activeAccent,
                        ),
                      ),
                      const Spacer(),
                      if ((_fontScale - 1.0).abs() > 0.01)
                        LuminousFeedback(
                          onTap: () {
                            if (appState.hapticsEnabled) {
                              HapticFeedback.selectionClick();
                            }
                            setState(() => _fontScale = 1.0);
                            appState.setLyricsFontScale(1.0);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: GlassSurface(
                            borderRadius: BorderRadius.circular(10),
                            style: GlassStyle.clear,
                            borderless: false,
                            tintColor: activeAccent.withOpacity(isDark ? 0.22 : 0.14),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            child: Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : activeAccent,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'A',
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: activeAccent,
                            inactiveTrackColor: isDark
                                ? Colors.white.withOpacity(0.16)
                                : Colors.black.withOpacity(0.14),
                            thumbColor: Colors.white,
                            trackHeight: 4.0,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                          ),
                          child: Slider(
                            value: _fontScale,
                            min: 0.7,
                            max: 1.5,
                            onChanged: (val) {
                              setState(() => _fontScale = val);
                              appState.setLyricsFontScale(val);
                            },
                          ),
                        ),
                      ),
                      Text(
                        'A',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Alignment: Clear vs Liquid Glass Toggle Chips
                  Text(
                    'Alignment',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _GlassChipToggle(
                          label: 'Auto',
                          selected: !_centered,
                          accent: activeAccent,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          onTap: () {
                            if (appState.hapticsEnabled) {
                              HapticFeedback.selectionClick();
                            }
                            setState(() => _centered = false);
                            appState.setLyricsCentered(false);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _GlassChipToggle(
                          label: 'Center',
                          selected: _centered,
                          accent: activeAccent,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          onTap: () {
                            if (appState.hapticsEnabled) {
                              HapticFeedback.selectionClick();
                            }
                            setState(() => _centered = true);
                            appState.setLyricsCentered(true);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Lyrics Style: Clear vs Liquid Glass Toggle Chips
                  Text(
                    'Lyrics style',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _GlassChipToggle(
                          label: 'Default',
                          selected: _style == 'default',
                          accent: activeAccent,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          onTap: () {
                            if (appState.hapticsEnabled) {
                              HapticFeedback.selectionClick();
                            }
                            setState(() => _style = 'default');
                            appState.setLyricsStyle('default');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _GlassChipToggle(
                          label: 'Flow',
                          selected: _style == 'flow',
                          accent: activeAccent,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          onTap: () {
                            if (appState.hapticsEnabled) {
                              HapticFeedback.selectionClick();
                            }
                            setState(() => _style = 'flow');
                            appState.setLyricsStyle('flow');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _GlassChipToggle(
                          label: 'Halo',
                          selected: _style == 'halo',
                          accent: activeAccent,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          onTap: () {
                            if (appState.hapticsEnabled) {
                              HapticFeedback.selectionClick();
                            }
                            setState(() => _style = 'halo');
                            appState.setLyricsStyle('halo');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _styleDescription(_style),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: subTextColor,
                    ),
                  ),

                  if (widget.parsed.isSynced) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: subTextColor,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Sync offset',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                        _ClearGlassStepButton(
                          icon: Icons.remove_rounded,
                          textColor: textColor,
                          onTap: () {
                            if (appState.hapticsEnabled) {
                              HapticFeedback.selectionClick();
                            }
                            final next = (_offsetMs - 100).clamp(-3000, 3000);
                            setState(() => _offsetMs = next);
                            appState.setLyricsOffsetMs(next);
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: GestureDetector(
                            onTap: _offsetMs != 0
                                ? () {
                                    if (appState.hapticsEnabled) {
                                      HapticFeedback.selectionClick();
                                    }
                                    setState(() => _offsetMs = 0);
                                    appState.setLyricsOffsetMs(0);
                                  }
                                : null,
                            child: Text(
                              '${_offsetMs >= 0 ? '+' : ''}$_offsetMs ms',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color:
                                    _offsetMs == 0 ? subTextColor : activeAccent,
                              ),
                            ),
                          ),
                        ),
                        _ClearGlassStepButton(
                          icon: Icons.add_rounded,
                          textColor: textColor,
                          onTap: () {
                            if (appState.hapticsEnabled) {
                              HapticFeedback.selectionClick();
                            }
                            final next = (_offsetMs + 100).clamp(-3000, 3000);
                            setState(() => _offsetMs = next);
                            appState.setLyricsOffsetMs(next);
                          },
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Primary Done Capsule: Prominent Liquid Glass Variant
                  LuminousFeedback(
                    onTap: () {
                      if (appState.hapticsEnabled) {
                        HapticFeedback.selectionClick();
                      }
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: activeAccent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.30 : 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.getOnAccentColor(activeAccent, isDark: isDark),
                          ),
                        ),
                      ),
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
}

class _ClearGlassActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  final VoidCallback onTap;

  const _ClearGlassActionTile({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LuminousFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(14),
        style: GlassStyle.clear,
        borderless: false,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: textColor.withOpacity(0.88)),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassChipToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final Color textColor;
  final Color subTextColor;
  final VoidCallback onTap;

  const _GlassChipToggle({
    required this.label,
    required this.selected,
    required this.accent,
    required this.textColor,
    required this.subTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isCurrentDark(context);
    return LuminousFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(
                  color: accent.withOpacity(isDark ? 0.85 : 0.65),
                  width: 1.3,
                )
              : null,
        ),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(12),
          style: selected ? GlassStyle.liquid : GlassStyle.clear,
          borderless: selected,
          tintColor: selected ? accent.withOpacity(isDark ? 0.28 : 0.16) : null,
          child: SizedBox(
            height: 36,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? textColor : subTextColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClearGlassStepButton extends StatelessWidget {
  final IconData icon;
  final Color textColor;
  final VoidCallback onTap;

  const _ClearGlassStepButton({
    required this.icon,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LuminousFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(15),
        style: GlassStyle.clear,
        borderless: false,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 16, color: textColor),
        ),
      ),
    );
  }
}
