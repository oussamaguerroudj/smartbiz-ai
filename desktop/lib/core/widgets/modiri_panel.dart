import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ModiriPanel extends StatelessWidget {
  final Widget child;
  final double blur;
  final double? opacity;
  final Color? color;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;

  const ModiriPanel({
    super.key,
    required this.child,
    this.blur = 16.0,
    this.opacity,
    this.color,
    this.borderRadius,
    this.border,
    this.padding,
    this.margin,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = borderRadius ?? BorderRadius.circular(16);

    final bg = color ??
        (isDark
            ? ModiriColors.ink800.withOpacity(opacity ?? 0.75)
            : ModiriColors.lightInk900);

    final b = border ??
        Border.all(
          color: isDark ? ModiriColors.lineDark : ModiriColors.lineLight,
          width: 1,
        );

    final shadow = isDark
        ? [
            const BoxShadow(
              color: Color(0x66000000),
              offset: Offset(0, 20),
              blurRadius: 40,
              spreadRadius: -20,
            ),
          ]
        : [
            const BoxShadow(
              color: Color(0x0D000000),
              offset: Offset(0, 10),
              blurRadius: 25,
              spreadRadius: -5,
            ),
          ];

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: r,
              border: b,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
