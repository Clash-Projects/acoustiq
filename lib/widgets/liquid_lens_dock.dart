import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../ui/theme/colors.dart';

/// Production-grade 3D Liquid Lens Navigation Dock
///
/// Faithfully reproduces the physical 3D optical lens from KowSU & iOS Vision:
/// 1. Real physical 3D lens optics: Top specular arc reflection, bottom caustic rim,
///    convex refraction gradient, and soft ambient depth shadow.
/// 2. Fluid drag & spring gesture: Dragging glides the 3D lens directly under the user's
///    finger in real time with selection haptics, springing smoothly to the nearest tab on release.
/// 3. Zero border outlines: Authentic optical glass without fake white sticker borders.
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

class _LiquidLensNavBarState extends State<LiquidLensNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animX;

  static const List<({IconData icon, String label})> _tabs = [
    (icon: Icons.graphic_eq_rounded, label: 'Inspect'),
    (icon: Icons.library_music_rounded, label: 'Audit'),
    (icon: Icons.copy_all_rounded, label: 'Duplicates'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  final List<GlobalKey> _tabKeys = List.generate(4, (_) => GlobalKey());
  final GlobalKey _dockKey = GlobalKey();

  double _currentLensX = 0.0;
  double _lensWidth = 84.0;
  bool _isDragging = false;
  int _lastHapticIndex = -1;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _animController.addListener(() {
      if (!_isDragging) {
        setState(() {
          _currentLensX = _animX.value;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snapToTab(widget.currentIndex, animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant LiquidLensNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && !_isDragging) {
      _snapToTab(widget.currentIndex, animate: true);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _snapToTab(int index, {bool animate = true}) {
    if (index < 0 || index >= _tabs.length) return;
    final dockBox = _dockKey.currentContext?.findRenderObject() as RenderBox?;
    final tabBox = _tabKeys[index].currentContext?.findRenderObject() as RenderBox?;

    if (dockBox != null && tabBox != null) {
      final tabOffset = tabBox.localToGlobal(Offset.zero, ancestor: dockBox);
      final targetX = tabOffset.dx;
      final targetWidth = tabBox.size.width;

      setState(() {
        _lensWidth = targetWidth;
      });

      if (!animate) {
        setState(() {
          _currentLensX = targetX;
        });
      } else {
        _animX = Tween<double>(begin: _currentLensX, end: targetX).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Curves.easeOutBack,
          ),
        );
        _animController.forward(from: 0.0);
      }
    }
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _animController.stop();
    _handleDragUpdate(details.globalPosition);
  }

  void _handleDragUpdate(Offset globalPos) {
    final dockBox = _dockKey.currentContext?.findRenderObject() as RenderBox?;
    if (dockBox == null) return;

    final local = dockBox.globalToLocal(globalPos);
    final clampedX = (local.dx - _lensWidth / 2)
        .clamp(6.0, dockBox.size.width - _lensWidth - 6.0);

    setState(() {
      _currentLensX = clampedX;
    });

    // Detect closest tab for live haptics
    int closestIndex = 0;
    double closestDist = double.infinity;

    for (int i = 0; i < _tabs.length; i++) {
      final tabBox = _tabKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (tabBox != null) {
        final tabOffset = tabBox.localToGlobal(Offset.zero, ancestor: dockBox);
        final dist = (tabOffset.dx - clampedX).abs();
        if (dist < closestDist) {
          closestDist = dist;
          closestIndex = i;
        }
      }
    }

    if (closestIndex != _lastHapticIndex) {
      _lastHapticIndex = closestIndex;
      if (appState.hapticsEnabled) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
    final dockBox = _dockKey.currentContext?.findRenderObject() as RenderBox?;
    if (dockBox == null) return;

    int targetIndex = widget.currentIndex;
    double closestDist = double.infinity;

    for (int i = 0; i < _tabs.length; i++) {
      final tabBox = _tabKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (tabBox != null) {
        final tabOffset = tabBox.localToGlobal(Offset.zero, ancestor: dockBox);
        final dist = (tabOffset.dx - _currentLensX).abs();
        if (dist < closestDist) {
          closestDist = dist;
          targetIndex = i;
        }
      }
    }

    widget.onTabSelected(targetIndex);
    _snapToTab(targetIndex, animate: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDark = appState.isCurrentDark(context);
        final useGlass = appState.isLiquidGlass;

        final dockBg = isDark
            ? (useGlass ? const Color(0xE6121212) : const Color(0xFF161616))
            : (useGlass ? Colors.white.withOpacity(0.88) : Colors.white);

        return Center(
          child: GestureDetector(
            onHorizontalDragStart: _handleDragStart,
            onHorizontalDragUpdate: (d) => _handleDragUpdate(d.globalPosition),
            onHorizontalDragEnd: _handleDragEnd,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: BackdropFilter(
                filter: useGlass
                    ? ImageFilter.blur(sigmaX: 20, sigmaY: 20)
                    : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Container(
                  key: _dockKey,
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: BoxDecoration(
                    color: dockBg,
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // 1. The 3D Liquid Lens Droplet
                      Positioned(
                        left: _currentLensX,
                        top: 0,
                        bottom: 0,
                        width: _lensWidth,
                        child: _LiquidLensDroplet(
                          isDark: isDark,
                          isDragging: _isDragging,
                        ),
                      ),

                      // 2. Interactive Navigation Tabs
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_tabs.length, (index) {
                          final tab = _tabs[index];
                          final isSelected = widget.currentIndex == index;

                          return Padding(
                            key: _tabKeys[index],
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _NavBarTabItem(
                              label: tab.label,
                              icon: tab.icon,
                              isSelected: isSelected,
                              isDark: isDark,
                              onTap: () {
                                if (appState.hapticsEnabled) {
                                  HapticFeedback.selectionClick();
                                }
                                widget.onTabSelected(index);
                                _snapToTab(index, animate: true);
                              },
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The Physical 3D Optical Liquid Lens Droplet
class _LiquidLensDroplet extends StatelessWidget {
  final bool isDark;
  final bool isDragging;

  const _LiquidLensDroplet({
    required this.isDark,
    required this.isDragging,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isDragging ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: CustomPaint(
        painter: _OpticalLensPainter(isDark: isDark),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CustomPainter rendering 3D Snell's Law Reflections (Top Specular Arc & Bottom Caustic Rim)
class _OpticalLensPainter extends CustomPainter {
  final bool isDark;

  _OpticalLensPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(25),
    );

    // 1. Convex Lens Gradient Body
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.04),
              ]
            : [
                Colors.white.withOpacity(0.95),
                Colors.white.withOpacity(0.70),
              ],
      ).createShader(Offset.zero & size);

    canvas.drawRRect(rrect, bodyPaint);

    // 2. Top Specular Arc Highlight (Light bouncing off top curved glass rim)
    final topHighlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.45],
        colors: isDark
            ? [
                Colors.white.withOpacity(0.55),
                Colors.transparent,
              ]
            : [
                Colors.white,
                Colors.transparent,
              ],
      ).createShader(Offset.zero & size);

    canvas.drawRRect(rrect, topHighlightPaint);

    // 3. Bottom Caustic Refraction Rim (Light bending out of lower edge)
    final bottomRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        stops: const [0.0, 0.35],
        colors: isDark
            ? [
                const Color(0x3800D2FF), // Subtle cyan optical refraction
                Colors.transparent,
              ]
            : [
                Colors.black.withOpacity(0.08),
                Colors.transparent,
              ],
      ).createShader(Offset.zero & size);

    canvas.drawRRect(rrect, bottomRimPaint);
  }

  @override
  bool shouldRepaint(covariant _OpticalLensPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

class _NavBarTabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavBarTabItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.white : const Color(0xFF007299);
    final inactiveColor = isDark ? const Color(0x73FFFFFF) : const Color(0x80000000);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        highlightColor: Colors.transparent,
        splashColor: AppColors.accentPrimary.withOpacity(0.12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.fastOutSlowIn,
          height: 48,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 18 : 12,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 21,
                color: isSelected ? activeColor : inactiveColor,
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.fastOutSlowIn,
                  alignment: Alignment.centerLeft,
                  child: isSelected
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 7),
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: activeColor,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
