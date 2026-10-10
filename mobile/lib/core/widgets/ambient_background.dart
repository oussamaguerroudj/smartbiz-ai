import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Ambient radial background providing the Cyber-Navy glow effect.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
    this.showGlow = true,
  });

  final Widget child;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDark) {
      return Container(
        color: AppColors.backgroundLight,
        child: child,
      );
    }

    return Container(
      color: AppColors.cyberNavy,
      child: Stack(
        children: [
          if (showGlow) ...[
            // Top-right electric blue glow
            Positioned(
              top: -120,
              right: -120,
              width: 500,
              height: 500,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.electricBlue.withValues(alpha: 0.12),
                        AppColors.electricBlue.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Bottom-left AI violet glow
            Positioned(
              bottom: -150,
              left: -150,
              width: 550,
              height: 550,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.aiViolet.withValues(alpha: 0.10),
                        AppColors.aiViolet.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          child,
        ],
      ),
    );
  }
}
