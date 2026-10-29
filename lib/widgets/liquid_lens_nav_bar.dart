import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';

class LiquidLensNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const LiquidLensNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<LiquidLensNavBar> createState() => _LiquidLensNavBarState();
}

class _LiquidLensNavBarState extends State<LiquidLensNavBar> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animPosition;
  double _currentFraction = 0.0;
  bool _isDragging = false;

  final List<({IconData icon, String label})> _tabs = const [
    (icon: Icons.graphic_eq_rounded, label: 'Inspect'),
    (icon: Icons.library_music_rounded, label: 'Library Audit'),
    (icon: Icons.copy_all_rounded, label: 'Duplicates'),
  ];

  @override
  void initState() {
    super.initState();
    _currentFraction = widget.currentIndex.toDouble();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _animPosition = Tween<double>(begin: _currentFraction, end: _currentFraction).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
  }

  @override
  void didUpdateWidget(covariant LiquidLensNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && !_isDragging) {
      _animateToTab(widget.currentIndex);
    }
  }

  void _animateToTab(int targetIndex) {
    if (appState.hapticsEnabled) {
      HapticFeedback.lightImpact();
    }
    _animPosition = Tween<double>(
      begin: _currentFraction,
      end: targetIndex.toDouble(),
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack))
      ..addListener(() {
        setState(() {
          _currentFraction = _animPosition.value;
        });
      });
    _animController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const trackHeight = 56.0;
        const lensHeight = 66.0;
        final tabWidth = totalWidth / _tabs.length;
        final lensWidth = tabWidth - 8.0;

        // Position of the lens center
        final lensLeft = (_currentFraction * tabWidth) + 4.0;

        return GestureDetector(
          onHorizontalDragStart: (details) {
            _isDragging = true;
            _animController.stop();
          },
          onHorizontalDragUpdate: (details) {
            setState(() {
              _currentFraction = (_currentFraction + (details.primaryDelta ?? 0) / tabWidth).clamp(0.0, 2.0);
            });
          },
          onHorizontalDragEnd: (details) {
            _isDragging = false;
            final targetTab = _currentFraction.round().clamp(0, 2);
            widget.onTabSelected(targetTab);
            _animateToTab(targetTab);
          },
          child: SizedBox(
            height: lensHeight + 6,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1. Dark Frosted Capsule Track
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: trackHeight,
                      decoration: BoxDecoration(
                        color: appState.isAmoled
                            ? const Color(0xFF0A0C12).withOpacity(0.85)
                            : const Color(0xFF141822).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. The 3D Liquid Glass Lens Indicator (Floating over track)
                Positioned(
                  left: lensLeft,
                  top: (trackHeight - lensHeight) / 2 + 3,
                  width: lensWidth,
                  height: lensHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          // Subtle 3D Glass Gradient
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.24),
                              Colors.white.withOpacity(0.05),
                              Colors.white.withOpacity(0.02),
                            ],
                          ),
                          // Specular curved rim reflection on top and bottom
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(0.90),
                              width: 1.5,
                            ),
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(0.35),
                              width: 1.0,
                            ),
                            left: BorderSide(
                              color: Colors.white.withOpacity(0.25),
                              width: 1.0,
                            ),
                            right: BorderSide(
                              color: Colors.white.withOpacity(0.25),
                              width: 1.0,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.45),
                              blurRadius: 18,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: const Color(0xFF00D2FF).withOpacity(0.18),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Tab Items (Icons + Labels)
                Row(
                  children: List.generate(_tabs.length, (index) {
                    final isCurrent = index == widget.currentIndex;
                    final tab = _tabs[index];

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          widget.onTabSelected(index);
                          _animateToTab(index);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isCurrent ? 1.0 : 0.50,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tab.icon,
                                  size: isCurrent ? 22 : 20,
                                  color: isCurrent ? Colors.white : Colors.white70,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  tab.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                    color: isCurrent ? Colors.white : Colors.white60,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
