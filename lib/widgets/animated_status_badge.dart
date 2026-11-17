import 'package:flutter/material.dart';

/// Authentic Material Status Badge for AcoustiQ.
/// Uses the official Material icons:
/// - Genuine: Icons.verified_rounded (scalloped 12-point seal)
/// - Suspicious: Icons.warning_amber_rounded
/// - Fake: Icons.cancel_rounded
///
/// Features a crisp, native micro-scale entry animation (zero blurry glowing halo).
class AnimatedStatusBadge extends StatefulWidget {
  final String status; // 'genuine', 'suspicious', 'fake'
  final Color color;
  final double size;
  final bool animatePulse;

  const AnimatedStatusBadge({
    super.key,
    required this.status,
    required this.color,
    this.size = 18.0,
    this.animatePulse = false,
  });

  @override
  State<AnimatedStatusBadge> createState() => _AnimatedStatusBadgeState();
}

class _AnimatedStatusBadgeState extends State<AnimatedStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scaleAnimation = Tween<double>(begin: 0.80, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getIcon() {
    switch (widget.status) {
      case 'genuine':
        return Icons.verified_rounded;
      case 'suspicious':
        return Icons.warning_amber_rounded;
      case 'untested':
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'fake':
      default:
        return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getIcon();

    if (!widget.animatePulse) {
      return Icon(
        icon,
        size: widget.size,
        color: widget.color,
      );
    }

    return RepaintBoundary(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Icon(
          icon,
          size: widget.size,
          color: widget.color,
        ),
      ),
    );
  }
}
