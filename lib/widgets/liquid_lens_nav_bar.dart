import 'dart:math' as math;
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

class _LiquidLensNavBarState extends State<LiquidLensNavBar> with TickerProviderStateMixin {
  late AnimationController _springController;
  late AnimationController _morphController; // 0.0 resting -> 1.0 active hold
  double _currentX = 0.0;
  double _targetX = 0.0;
  double _dragVelocityX = 0.0;
  bool _isInteracting = false;

  final List<({IconData icon, String label})> _tabs = const [
    (icon: Icons.graphic_eq_rounded, label: 'Inspect'),
    (icon: Icons.library_music_rounded, label: 'Audit'),
    (icon: Icons.copy_all_rounded, label: 'Duplicates'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _springController.dispose();
    _morphController.dispose();
    super.dispose();
  }

  void _snapToTab(int tabIndex, double tabWidth) {
    _targetX = tabIndex * tabWidth;
    final startX = _currentX;

    _springController.stop();
    final anim = Tween<double>(begin: startX, end: _targetX).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
    );

    anim.addListener(() {
      setState(() {
        _currentX = anim.value;
      });
    });

    _springController.forward(from: 0.0);
    _morphController.reverse(); // Fade out the 3D liquid bubble back to resting state
    _isInteracting = false;

    if (tabIndex != widget.currentIndex) {
      if (appState.hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
      widget.onTabSelected(tabIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appState, _springController, _morphController]),
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);

        return LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            const barHeight = 58.0;
            final tabWidth = totalWidth / _tabs.length;

            if (!_isInteracting && !_springController.isAnimating) {
              _currentX = widget.currentIndex * tabWidth;
            }

            // Boundary Squeeze / Elastic Stretch calculation
            final minX = 0.0;
            final maxX = (_tabs.length - 1) * tabWidth;

            double squeezeX = 1.0;
            double bulgeY = 1.0;

            if (_currentX < minX) {
              // Left wall collision squeeze
              final overshoot = (minX - _currentX).clamp(0.0, 40.0);
              squeezeX = 1.0 - (overshoot / 40.0) * 0.32; // squeeze width up to 32%
              bulgeY = 1.0 + (overshoot / 40.0) * 0.16;   // bulge height
            } else if (_currentX > maxX) {
              // Right wall collision squeeze
              final overshoot = (_currentX - maxX).clamp(0.0, 40.0);
              squeezeX = 1.0 - (overshoot / 40.0) * 0.32;
              bulgeY = 1.0 + (overshoot / 40.0) * 0.16;
            } else if (_dragVelocityX.abs() > 0.5) {
              // Fluid velocity stretch along movement axis
              final vFactor = (_dragVelocityX.abs() / 15.0).clamp(0.0, 0.25);
              squeezeX = 1.0 + vFactor;
              bulgeY = 1.0 - (vFactor * 0.4);
            }

            // Lens dimensions
            final lensWidth = (tabWidth - 6.0) * squeezeX;
            final lensHeight = 52.0 * bulgeY;
            final lensLeft = _currentX + (tabWidth - lensWidth) / 2;

            return Listener(
              onPointerDown: (event) {
                _isInteracting = true;
                _springController.stop();
                _morphController.forward(); // Expand the 3D liquid bubble
                if (appState.hapticsEnabled) {
                  HapticFeedback.lightImpact();
                }
                setState(() {
                  _dragVelocityX = 0.0;
                  final localX = (event.localPosition.dx - (tabWidth / 2)).clamp(-30.0, maxX + 30.0);
                  _currentX = localX;
                });
              },
              onPointerMove: (event) {
                setState(() {
                  _dragVelocityX = event.delta.dx;
                  // Rubber band resistance past edges
                  double newX = _currentX + event.delta.dx;
                  if (newX < minX) {
                    newX = minX - (minX - newX) * 0.45;
                  } else if (newX > maxX) {
                    newX = maxX + (newX - maxX) * 0.45;
                  }
                  _currentX = newX;
                });
              },
              onPointerUp: (event) {
                final nearestTab = (_currentX / tabWidth).round().clamp(0, _tabs.length - 1);
                _snapToTab(nearestTab, tabWidth);
              },
              onPointerCancel: (event) {
                final nearestTab = (_currentX / tabWidth).round().clamp(0, _tabs.length - 1);
                _snapToTab(nearestTab, tabWidth);
              },
              child: SizedBox(
                height: barHeight + 6,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // 1. Frosted Translucent Capsule Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: isDark
                                ? (appState.isAmoled
                                    ? Colors.white.withOpacity(0.04)
                                    : const Color(0xFF141824).withOpacity(0.85))
                                : Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(30),
                            border: Border(
                              top: BorderSide(
                                color: Colors.white.withOpacity(isDark ? 0.16 : 0.40),
                                width: 1.2,
                              ),
                              left: BorderSide(color: Colors.white.withOpacity(isDark ? 0.08 : 0.20), width: 1.0),
                              right: BorderSide(color: Colors.white.withOpacity(isDark ? 0.08 : 0.20), width: 1.0),
                              bottom: BorderSide(color: Colors.white.withOpacity(isDark ? 0.05 : 0.10), width: 1.0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.40 : 0.10),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 2. Resting Pill Indicator (KowSU Image 2 style: subtle cyan pill behind active tab)
                    if (!_isInteracting && _morphController.value < 0.1)
                      Positioned(
                        left: widget.currentIndex * tabWidth + (tabWidth - (tabWidth - 10)) / 2,
                        width: tabWidth - 10,
                        height: barHeight - 12,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D2FF).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF00D2FF).withOpacity(0.25),
                              width: 1.0,
                            ),
                          ),
                        ),
                      ),

                    // 3. Dynamic 3D Liquid Glass Drop (emerges during touch/hold/drag with refraction)
                    if (_morphController.value > 0.01)
                      Positioned(
                        left: lensLeft,
                        width: lensWidth,
                        height: lensHeight,
                        child: Opacity(
                          opacity: _morphController.value.clamp(0.0, 1.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  // Translucent liquid refraction gradient
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withOpacity(0.22),
                                      Colors.white.withOpacity(0.04),
                                      Colors.white.withOpacity(0.02),
                                    ],
                                  ),
                                  // Specular top optical rim reflection & bottom bounce
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.white.withOpacity(0.92),
                                      width: 1.4,
                                    ),
                                    bottom: BorderSide(
                                      color: Colors.white.withOpacity(0.35),
                                      width: 1.0,
                                    ),
                                    left: BorderSide(
                                      color: Colors.white.withOpacity(0.20),
                                      width: 1.0,
                                    ),
                                    right: BorderSide(
                                      color: Colors.white.withOpacity(0.20),
                                      width: 1.0,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00D2FF).withOpacity(0.25),
                                      blurRadius: 14,
                                      spreadRadius: -2,
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.40),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // 4. Tab Items (Icons + Labels)
                    Row(
                      children: List.generate(_tabs.length, (index) {
                        final isSelected = index == widget.currentIndex;
                        final tab = _tabs[index];

                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _snapToTab(index, tabWidth);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    tab.icon,
                                    size: 21,
                                    color: isSelected
                                        ? const Color(0xFF00D2FF)
                                        : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                  const SizedBox(height: 2.5),
                                  Text(
                                    tab.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF00D2FF)
                                          : (isDark ? Colors.white54 : Colors.black45),
                                      letterSpacing: 0.15,
                                    ),
                                  ),
                                ],
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
      },
    );
  }
}
