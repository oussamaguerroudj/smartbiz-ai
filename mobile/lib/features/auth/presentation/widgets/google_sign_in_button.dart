import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Renders a sharp, native vector Google "G" logo without external image assets.
class GoogleLogoWidget extends StatelessWidget {
  const GoogleLogoWidget({super.key, this.size = 20.0});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double center = size.width / 2;
    final double strokeWidth = size.width * 0.22;
    final double radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: Offset(center, center), radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Red arc (top): -140° to -40°
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -math.pi * 0.78, math.pi * 0.56, false, paint);

    // Blue arc (right): -40° to +40°
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -math.pi * 0.22, math.pi * 0.44, false, paint);

    // Green arc (bottom): +40° to +140°
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, math.pi * 0.22, math.pi * 0.56, false, paint);

    // Yellow arc (left): +140° to +220°
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, math.pi * 0.78, math.pi * 0.44, false, paint);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barHeight = strokeWidth;
    final barWidth = radius + (strokeWidth / 2);
    canvas.drawRect(
      Rect.fromLTWH(
        center - 1,
        center - (barHeight / 2),
        barWidth + 1,
        barHeight,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official styled "Continue with Google" button.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final String label = locale == 'ar'
        ? 'المتابعة باستخدام Google'
        : (locale == 'fr' ? 'Continuer avec Google' : 'Continue with Google');

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white : Colors.black87,
        backgroundColor: isDark ? const Color(0xFF1E2235) : Colors.white,
        side: BorderSide(
          color: isDark ? const Color(0xFF2E3450) : const Color(0xFFDADCE0),
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        elevation: 0,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GoogleLogoWidget(size: 20),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF3C4043),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
