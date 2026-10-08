import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The one brand gradient (deep ink → indigo) reused everywhere the app
/// wants a "hero" moment: Splash, Onboarding, the top of the Dashboard,
/// and the AI Assistant background. One consistent gradient, not a new
/// one per screen, so these moments read as the same product.
class GradientHero extends StatelessWidget {
  const GradientHero({super.key, required this.child, this.borderRadius});

  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          begin: Alignment(-0.4, -1),
          end: Alignment(0.6, 1),
          colors: AppColors.heroGradient,
        ),
      ),
      child: child,
    );
  }
}

/// A soft, looping "breathing" scale+glow animation for a circular icon  - 
/// used on Splash (logo) and Onboarding (slide icon) so the brand feels
/// alive on first launch. This is the one deliberate looping motion in
/// the app; everything else answers a user action instead of looping.
class BreathingIcon extends StatefulWidget {
  const BreathingIcon({
    super.key,
    required this.child,
    this.size = 84,
  });

  final Widget child;
  final double size;

  @override
  State<BreathingIcon> createState() => _BreathingIconState();
}

class _BreathingIconState extends State<BreathingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = 1.0 + (0.06 * t);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            alignment: Alignment.center,
            child: widget.child,
          ),
        );
      },
    );
  }
}
