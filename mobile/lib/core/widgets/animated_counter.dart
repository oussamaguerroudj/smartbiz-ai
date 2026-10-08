import 'package:flutter/material.dart';

/// Animates a numeric value counting up from 0 (or from its previous
/// value) to [value] whenever it changes, instead of a KPI number simply
/// popping into place. Formats with thousands separators by default,
/// matching how the rest of the app displays DZD amounts.
///
/// Motion here answers real data arriving (the dashboard/report loading),
/// not decoration  -  it plays once per value change, not on a loop.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
    this.duration = const Duration(milliseconds: 700),
  });

  final double value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final int decimals;
  final Duration duration;

  String _format(double v) {
    final fixed = v.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final negative = intPart.startsWith('-');
    final digits = negative ? intPart.substring(1) : intPart;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    final withSign = (negative ? '-' : '') + buffer.toString();
    return parts.length > 1 ? '$withSign.${parts[1]}' : withSign;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return Text(
          '$prefix${_format(animatedValue)}$suffix',
          style: style,
        );
      },
    );
  }
}
