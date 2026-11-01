import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../ui/theme/colors.dart';
import 'glass_surface.dart';
import 'luminous_feedback.dart';
import 'app_snack_bar.dart';

/// Shows an Apple WWDC25 Frosted Glass modal bottom sheet displaying
/// embedded Vorbis FLAC lyrics (synced LRC timestamps or plain text).
void showLyricsViewerSheet(BuildContext context, FlacInfo track) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => LyricsViewerSheet(track: track),
  );
}

class LyricsViewerSheet extends StatelessWidget {
  final FlacInfo track;

  const LyricsViewerSheet({super.key, required this.track});

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);
    final activeAccent = appState.getAccentColor(context);

    final rawLyrics = track.lyrics?.trim() ?? '';
    final hasLrcRegex = RegExp(r'\[\d{2}:\d{2}[\.:]\d{2,3}\]').hasMatch(rawLyrics);

    final List<_LrcLine> parsedLines = [];
    bool isTrulySynced = false;

    if (hasLrcRegex) {
      final lines = rawLyrics.split(RegExp(r'\r?\n'));
      final lrcRegex = RegExp(r'\[(\d{2}:\d{2}[\.:]\d{2,3})\](.*)');
      for (final l in lines) {
        final match = lrcRegex.firstMatch(l.trim());
        if (match != null) {
          final time = match.group(1) ?? '';
          final text = match.group(2)?.trim() ?? '';
          if (text.isNotEmpty || time.isNotEmpty) {
            parsedLines.add(_LrcLine(timestamp: time, text: text));
            // Check if timestamp is non-zero
            final digitsOnly = time.replaceAll(RegExp(r'[^0-9]'), '');
            final numericVal = int.tryParse(digitsOnly) ?? 0;
            if (numericVal > 0) {
              isTrulySynced = true;
            }
          }
        } else if (l.trim().isNotEmpty) {
          parsedLines.add(_LrcLine(timestamp: null, text: l.trim()));
        }
      }
    }

    final isSynced = hasLrcRegex && isTrulySynced;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    // Premium multi-lingual font stack (Hindi Devanagari + English typography)
    final lyricsTextStyle = TextStyle(
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Noto Sans Devanagari', 'Kohinoor Devanagari', 'sans-serif'],
      fontSize: 15.0,
      fontWeight: FontWeight.w500,
      height: 1.55,
      letterSpacing: -0.1,
      color: textColor,
    );

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: GlassSurface(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        style: GlassStyle.frosted,
        borderless: false,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
              const SizedBox(height: 14),

              // Header Bar
              Row(
                children: [
                  // 50dp Squircle Album Art
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x30FFFFFF) : const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: isDark
                          ? AppColors.softElevation(elevation: 2.5)
                          : AppColors.lightSoftElevation(elevation: 2.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: track.hasCover && track.coverBytes != null
                        ? Image.memory(track.coverBytes!, fit: BoxFit.cover)
                        : Center(
                            child: Icon(
                              Icons.lyrics_rounded,
                              size: 26,
                              color: activeAccent,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),

                  // Track Info & Badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title.isNotEmpty ? track.title : track.fileName,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['Noto Sans Devanagari', 'sans-serif'],
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artist.isNotEmpty ? track.artist : 'Unknown Artist',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['Noto Sans Devanagari', 'sans-serif'],
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: subTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),

                        // Badges Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSynced
                                    ? AppColors.genuineEmerald.withOpacity(isDark ? 0.22 : 0.14)
                                    : (isDark ? const Color(0x22FFFFFF) : const Color(0x18000000)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSynced
                                      ? AppColors.genuineEmerald.withOpacity(0.4)
                                      : (isDark ? const Color(0x22FFFFFF) : const Color(0x20000000)),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSynced ? Icons.timer_outlined : Icons.notes_rounded,
                                    size: 11,
                                    color: isSynced ? AppColors.genuineEmerald : subTextColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isSynced ? 'SYNCED LRC' : 'UNSYNCED / PLAIN',
                                    style: TextStyle(
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isSynced ? AppColors.genuineEmerald : subTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Copy All Lyrics Button
                  if (rawLyrics.isNotEmpty)
                    LuminousFeedback(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: rawLyrics));
                        if (appState.hapticsEnabled) {
                          HapticFeedback.lightImpact();
                        }
                        showThemedSnackBar(
                          context,
                          'Lyrics copied to clipboard',
                          icon: Icons.copy_rounded,
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0x20FFFFFF) : const Color(0x18000000),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(Icons.copy_rounded, size: 18, color: textColor),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 14),

              // Hairline separator
              Container(
                height: 1,
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0x12000000),
              ),

              const SizedBox(height: 10),

              // Scrollable Lyrics Body
              Expanded(
                child: rawLyrics.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lyrics_outlined,
                              size: 48,
                              color: subTextColor.withOpacity(0.4),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No lyrics metadata found in this FLAC file',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: subTextColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    : isSynced
                        ? ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: parsedLines.length,
                            itemBuilder: (context, index) {
                              final line = parsedLines[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (line.timestamp != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        margin: const EdgeInsets.only(right: 10, top: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0x25FFFFFF) : const Color(0x18000000),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          line.timestamp!,
                                          style: TextStyle(
                                            fontFamily: 'JetBrainsMono',
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: activeAccent,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        line.text.isEmpty ? '♪' : line.text,
                                        style: lyricsTextStyle.copyWith(
                                          color: line.text.isEmpty
                                              ? subTextColor.withOpacity(0.5)
                                              : textColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: SelectableText(
                                // Strip placeholder 00:00 timestamps if present
                                hasLrcRegex
                                    ? parsedLines.map((e) => e.text).join('\n')
                                    : rawLyrics,
                                style: lyricsTextStyle,
                              ),
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

class _LrcLine {
  final String? timestamp;
  final String text;

  _LrcLine({required this.timestamp, required this.text});
}
