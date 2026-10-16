import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ModiriBackground extends StatelessWidget {
  final Widget child;

  const ModiriBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? ModiriColors.ink950 : ModiriColors.lightInk950,
      ),
      child: Stack(
        children: [
          // Top-right radial glow
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 900,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ModiriColors.brandIndigo.withOpacity(isDark ? 0.16 : 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.65],
                ),
              ),
            ),
          ),
          // Bottom-left radial glow
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 800,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ModiriColors.brandBlue.withOpacity(isDark ? 0.12 : 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.60],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
