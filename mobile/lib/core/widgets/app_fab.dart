import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Wraps a standard [FloatingActionButton] with a one-shot scale+rotate
/// "bounce" on tap — matches the reference's
/// `.phone-block:hover .fab{transform:scale(1.08) rotate(90deg);}`.
/// Touch surfaces have no hover state, so the nearest faithful
/// equivalent is playing that same transform as a press response
/// instead of a persistent hover — same motion, triggered by the
/// closest thing a phone has to "the pointer is on me right now": a tap.
///
/// Also applies the reference's exact FAB shadow — a brand-tinted glow
/// (`box-shadow:0 10px 20px -6px rgba(61,85,245,.65)`, via
/// [AppSpacing.brandGlow]) instead of Material's default grey elevation
/// shadow.
class AppFab extends StatefulWidget {
  const AppFab({super.key, required this.onPressed, this.icon = Icons.add, this.tooltip});

  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;

  @override
  State<AppFab> createState() => _AppFabState();
}

class _AppFabState extends State<AppFab> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 45),
    TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 55),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  late final Animation<double> _rotation = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.25), weight: 45), // 90deg = 0.25 turn
    TweenSequenceItem(tween: Tween(begin: 0.25, end: 0.0), weight: 55),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: Transform.rotate(angle: _rotation.value * 2 * 3.14159265, child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: AppSpacing.brandGlow,
        ),
        child: FloatingActionButton(
          tooltip: widget.tooltip,
          elevation: 0,
          highlightElevation: 0,
          onPressed: _handleTap,
          child: Icon(widget.icon),
        ),
      ),
    );
  }
}
