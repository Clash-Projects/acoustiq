import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/native_audio_service.dart';
import '../ui/theme/colors.dart';
import 'glass_surface.dart';
import 'luminous_feedback.dart';

/// Shows Poweramp / LastWave inspired Audiophile Signal Path Inspector
void showSignalPathSheet(BuildContext context, {String? trackTitle, int? sampleRate, int? bitDepth}) {
  final active = appState.activeTrack;
  final resolvedTitle = trackTitle ?? (active?.title.isNotEmpty == true ? active!.title : active?.fileName);
  final resolvedRate = sampleRate ?? active?.sampleRate ?? 48000;
  final resolvedDepth = bitDepth ?? active?.bitDepth ?? 16;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SignalPathSheetView(
      trackTitle: resolvedTitle,
      sampleRate: resolvedRate,
      bitDepth: resolvedDepth,
    ),
  );
}

/// Dedicated USB DAC & Bit-Perfect Architecture Guide Sheet (Settings)
void showUsbDacGuideSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _UsbDacGuideSheetView(),
  );
}

class _SignalPathSheetView extends StatefulWidget {
  final String? trackTitle;
  final int sampleRate;
  final int bitDepth;

  const _SignalPathSheetView({
    this.trackTitle,
    this.sampleRate = 48000,
    this.bitDepth = 16,
  });

  @override
  State<_SignalPathSheetView> createState() => _SignalPathSheetViewState();
}

class _SignalPathSheetViewState extends State<_SignalPathSheetView> {
  Map<String, dynamic>? _engineStatus;
  bool _isLoading = true;
  bool _showGuide = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await NativeAudioService.instance.queryEngineStatus();
    if (mounted) {
      setState(() {
        _engineStatus = status;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);
    final activeAccent = appState.getAccentColor(context);

    final livePath = NativeAudioService.instance.signalPath;
    final hasUsbDac = _engineStatus?['hasUsbDac'] == true;
    final usbDacName = _engineStatus?['usbDacName']?.toString() ?? 'Device Audio Pipeline';
    final isBitPerfect = (_engineStatus?['isBitPerfect'] == true) || livePath.isBitPerfect;
    final activeDriver = _engineStatus?['activeDriver']?.toString() ?? livePath.driver;
    final activeEndpoint = _engineStatus?['endpoint']?.toString() ?? livePath.endpoint;
    final isUsbDirectActive = activeDriver.contains('USB') && isBitPerfect;
    final sampleRateStr = '${(widget.sampleRate / 1000).toStringAsFixed(1)} kHz';
    final bitDepthStr = '${widget.bitDepth}-bit';
    final Color statusColor = isUsbDirectActive
        ? AppColors.genuineEmerald
        : (hasUsbDac ? const Color(0xFFFFD700) : activeAccent);

    final nodes = [
      (
        step: '1',
        category: 'SOURCE FILE',
        tag: 'LOSSLESS',
        tagColor: const Color(0xFF38BDF8),
        value: widget.trackTitle ?? 'FLAC Audio Stream',
        spec: 'FLAC • $sampleRateStr • $bitDepthStr',
        icon: Icons.audio_file_rounded,
        color: const Color(0xFF38BDF8),
      ),
      (
        step: '2',
        category: 'PCM DECODER',
        tag: isUsbDirectActive ? 'UNITY 1:1' : 'FLOAT32',
        tagColor: AppColors.genuineEmerald,
        value: 'Multi-Depth PCM Unpack',
        spec: '$bitDepthStr → 32-bit Float • 0.0 dB Gain',
        icon: Icons.graphic_eq_rounded,
        color: AppColors.genuineEmerald,
      ),
      (
        step: '3',
        category: 'OUTPUT DRIVER',
        tag: isUsbDirectActive
            ? 'USB DIRECT'
            : (activeDriver.contains('MediaPlayer') ? 'MEDIAPLAYER' : activeDriver.toUpperCase()),
        tagColor: statusColor,
        value: activeDriver,
        spec: isUsbDirectActive
            ? 'Kernel usbfs Isochronous • Bypasses AudioFlinger'
            : 'Android Audio Mixer (Connect UAC DAC for Bit-Perfect)',
        icon: Icons.memory_rounded,
        color: statusColor,
      ),
      (
        step: '4',
        category: 'HARDWARE ENDPOINT',
        tag: isUsbDirectActive ? 'BIT-PERFECT' : (hasUsbDac ? 'USB DETECTED' : 'SHARED'),
        tagColor: statusColor,
        value: hasUsbDac ? usbDacName : activeEndpoint,
        spec: '$sampleRateStr Output Clock',
        icon: hasUsbDac ? Icons.usb_rounded : Icons.headphones_rounded,
        color: statusColor,
      ),
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: GlassSurface(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        style: GlassStyle.frosted,
        borderless: false,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pill handle
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
              const SizedBox(height: 16),

              // Header with Bit-Perfect Frosted Seal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor.withOpacity(isDark ? 0.22 : 0.15),
                        ),
                        child: Icon(
                          Icons.route_rounded,
                          size: 20,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Signal Path',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          Text(
                            isUsbDirectActive
                                ? 'Bit-Perfect USB Direct Pipeline'
                                : 'High-Res Audio Pipeline',
                            style: TextStyle(
                              fontSize: 12,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GlassSurface(
                    borderRadius: BorderRadius.circular(10),
                    style: GlassStyle.frosted,
                    borderless: false,
                    tintColor: statusColor.withOpacity(isDark ? 0.22 : 0.14),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isUsbDirectActive ? Icons.verified_rounded : Icons.graphic_eq_rounded,
                          size: 13,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isUsbDirectActive
                              ? 'USB BIT-PERFECT'
                              : (activeDriver.contains('MediaPlayer') ? 'SYSTEM MIXER' : 'STANDARD FLOAT'),
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Pipeline Stages List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        children: [
                          ...nodes.asMap().entries.map((entry) {
                            final i = entry.key;
                            final n = entry.value;
                            final isLast = i == nodes.length - 1;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Step indicator column with connecting line
                                Column(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: n.color.withOpacity(isDark ? 0.20 : 0.12),
                                        border: Border.all(
                                          color: n.color.withOpacity(0.40),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(n.icon, size: 16, color: n.color),
                                      ),
                                    ),
                                    if (!isLast)
                                      Container(
                                        width: 2,
                                        height: 48,
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        color: isDark ? const Color(0x30FFFFFF) : const Color(0x20000000),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                // Content Column (Zero Truncation Architecture)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2, bottom: 18),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Category row + frosted tag
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              n.category,
                                              style: TextStyle(
                                                fontFamily: 'JetBrainsMono',
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.6,
                                                color: subTextColor,
                                              ),
                                            ),
                                            GlassSurface(
                                              borderRadius: BorderRadius.circular(6),
                                              style: GlassStyle.clear,
                                              borderless: false,
                                              tintColor: n.tagColor.withOpacity(isDark ? 0.20 : 0.12),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              child: Text(
                                                n.tag,
                                                style: TextStyle(
                                                  fontFamily: 'JetBrainsMono',
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: n.tagColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        // Primary Value
                                        Text(
                                          n.value,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                          maxLines: 2,
                                          softWrap: true,
                                        ),
                                        const SizedBox(height: 3),
                                        // Technical Spec Note
                                        Text(
                                          n.spec,
                                          style: TextStyle(
                                            fontFamily: 'JetBrainsMono',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: n.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),

                          const SizedBox(height: 12),

                          // USB DAC Audiophile Guide Card
                          LuminousFeedback(
                            onTap: () => setState(() => _showGuide = !_showGuide),
                            borderRadius: BorderRadius.circular(18),
                            child: GlassSurface(
                              borderRadius: BorderRadius.circular(18),
                              style: GlassStyle.frosted,
                              borderless: false,
                              tintColor: const Color(0xFFFFD700).withOpacity(isDark ? 0.15 : 0.10),
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFFFD700).withOpacity(0.20),
                                        ),
                                        child: const Icon(Icons.usb_rounded, size: 16, color: Color(0xFFFFD700)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'USB DAC & Bit-Perfect Guide',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        _showGuide ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                        size: 20,
                                        color: subTextColor,
                                      ),
                                    ],
                                  ),
                                  if (_showGuide) ...[
                                    const SizedBox(height: 12),
                                    _buildGuideBullet(
                                      icon: Icons.power_rounded,
                                      title: 'Plug & Play Connectivity',
                                      detail: 'Connect any Type-C USB DAC (Moondrop, FiiO, Apple Dongle, iFi, etc.).',
                                      textColor: textColor,
                                      subTextColor: subTextColor,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildGuideBullet(
                                      icon: Icons.memory_rounded,
                                      title: 'Kernel usbfs Isochronous Driver',
                                      detail: 'Communicates directly with DAC hardware, bypassing Android AudioFlinger.',
                                      textColor: textColor,
                                      subTextColor: subTextColor,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildGuideBullet(
                                      icon: Icons.speed_rounded,
                                      title: 'True Audio Clocks (No 48kHz Resampling)',
                                      detail: 'Android forces 48kHz audio resampling. AcoustiQ feeds exact 44.1k, 96k, or 192k audio clocks bit-for-bit.',
                                      textColor: textColor,
                                      subTextColor: subTextColor,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildGuideBullet(
                                      icon: Icons.verified_rounded,
                                      title: 'Audiophile Volume & Dynamic Range',
                                      detail: 'Direct hardware volume curve preserves full 24-bit dynamic range without software clipping.',
                                      textColor: textColor,
                                      subTextColor: subTextColor,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 14),

              // Done Button in Frosted Glass
              LuminousFeedback(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(16),
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(16),
                  style: GlassStyle.frosted,
                  borderless: false,
                  tintColor: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Center(
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
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

  Widget _buildGuideBullet({
    required IconData icon,
    required String title,
    required String detail,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFFFD700)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
              ),
              const SizedBox(height: 1),
              Text(
                detail,
                style: TextStyle(fontSize: 11, color: subTextColor, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UsbDacGuideSheetView extends StatefulWidget {
  const _UsbDacGuideSheetView();

  @override
  State<_UsbDacGuideSheetView> createState() => _UsbDacGuideSheetViewState();
}

class _UsbDacGuideSheetViewState extends State<_UsbDacGuideSheetView> {
  Map<String, dynamic>? _engineStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await NativeAudioService.instance.queryEngineStatus();
    if (mounted) {
      setState(() {
        _engineStatus = status;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appState.isCurrentDark(context);
    final textColor = appState.getTextColor(context);
    final subTextColor = appState.getSubTextColor(context);
    final hasUsbDac = _engineStatus?['hasUsbDac'] == true;
    final usbDacName = _engineStatus?['usbDacName']?.toString() ?? 'No Type-C DAC connected';

    final guideSteps = [
      (
        icon: Icons.power_rounded,
        title: 'Plug & Play Type-C DACs',
        detail: 'Supports external USB DACs and dongles (Moondrop, FiiO, Apple, iFi).',
      ),
      (
        icon: Icons.memory_rounded,
        title: 'Kernel usbfs Bypass',
        detail: 'Streams PCM directly to USB hardware, bypassing Android AudioFlinger.',
      ),
      (
        icon: Icons.speed_rounded,
        title: 'Native Hardware Clocks',
        detail: 'Feeds exact 44.1 kHz, 96 kHz, or 192 kHz rates without 48 kHz resampling.',
      ),
      (
        icon: Icons.verified_rounded,
        title: 'Hardware Volume Curve',
        detail: 'Preserves full 24-bit dynamic range without software gain clipping.',
      ),
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: GlassSurface(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        style: GlassStyle.frosted,
        borderless: false,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFD700).withOpacity(isDark ? 0.22 : 0.14),
                    ),
                    child: const Icon(Icons.usb_rounded, size: 20, color: Color(0xFFFFD700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'USB DAC Bit-Perfect Guide',
                          style: TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          _isLoading
                              ? 'Checking USB audio interface...'
                              : (hasUsbDac ? 'Connected: $usbDacName' : usbDacName),
                          style: TextStyle(
                            fontSize: 12,
                            color: hasUsbDac ? const Color(0xFFFFD700) : subTextColor,
                            fontWeight: hasUsbDac ? FontWeight.w600 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: subTextColor,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: guideSteps.map((step) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0x18FFFFFF) : const Color(0x10000000),
                            width: 0.7,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withOpacity(isDark ? 0.18 : 0.12),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(step.icon, size: 16, color: const Color(0xFFFFD700)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    step.detail,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: subTextColor,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              LuminousFeedback(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(16),
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(16),
                  style: GlassStyle.frosted,
                  borderless: false,
                  tintColor: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Center(
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
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
