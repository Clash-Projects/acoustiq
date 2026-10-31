import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../models/flac_info.dart';
import '../ui/theme/colors.dart';
import 'glass_surface.dart';
import 'luminous_feedback.dart';

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
    final hasLrcTimestamps = RegExp(r'\[\d{2}:\d{2}[\.:]\d{2,3}\]').hasMatch(rawLyrics);

    final List<_LrcLine> parsedLines = [];
    if (hasLrcTimestamps) {
      final lines = rawLyrics.split(RegExp(r'\r?\n'));
      final lrcRegex = RegExp(r'\[(\d{2}:\d{2}[\.:]\d{2,3})\](.*)');
      for (final l in lines) {
        final match = lrcRegex.firstMatch(l.trim());
        if (match != null) {
          final time = match.group(1) ?? '';
          final text = match.group(2)?.trim() ?? '';
          if (text.isNotEmpty || time.isNotEmpty) {
            parsedLines.add(_LrcLine(timestamp: time, text: text));
          }
        } else if (l.trim().isNotEmpty) {
          parsedLines.add(_LrcLine(timestamp: null, text: l.trim()));
        }
      }
    }

    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: GlassSurface(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        style: GlassStyle.frosted,
        borderless: false,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                const SizedBox(width: 12),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title.isNotEmpty ? track.title : track.fileName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        track.artist.isNotEmpty ? track.artist : 'Embedded FLAC Lyrics',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: subTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Copy Lyrics Action Pill
                if (rawLyrics.isNotEmpty)
                  LuminousFeedback(
                    onTap: () {
                      if (appState.hapticsEnabled) HapticFeedback.selectionClick();
                      Clipboard.setData(ClipboardData(text: rawLyrics));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Lyrics copied to clipboard'),
                          backgroundColor: activeAccent,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: GlassSurface(
                      borderRadius: BorderRadius.circular(12),
                      style: GlassStyle.clear,
                      borderless: false,
                      tintColor: activeAccent.withOpacity(isDark ? 0.22 : 0.12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 13, color: activeAccent),
                          const SizedBox(width: 4),
                          Text(
                            'Copy',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: activeAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(width: 6),

                // Close Button
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: subTextColor),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Format Badge & Specs Pill
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withOpacity(isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.music_note_rounded, size: 12, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 4),
                      Text(
                        hasLrcTimestamps ? 'SYNCED LRC STREAM' : 'EMBEDDED VORBIS TEXT',
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${rawLyrics.split('\n').length} lines',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    color: subTextColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

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
                  : hasLrcTimestamps
                      ? ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: parsedLines.length,
                          itemBuilder: (context, index) {
                            final line = parsedLines[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
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
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1.45,
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
                              rawLyrics,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14.5,
                                height: 1.6,
                                fontWeight: FontWeight.w400,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
            ),
          ],
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
