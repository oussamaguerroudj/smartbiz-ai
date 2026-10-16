import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ModiriBadgeVariant {
  neutral,
  blue,
  emerald,
  amber,
  rose,
  violet,
}

class ModiriBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final ModiriBadgeVariant variant;
  final bool isPill;

  const ModiriBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = ModiriBadgeVariant.neutral,
    this.isPill = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color border;
    Color text;

    switch (variant) {
      case ModiriBadgeVariant.blue:
        bg = ModiriColors.brandBlue.withOpacity(isDark ? 0.20 : 0.10);
        border = ModiriColors.brandBlue.withOpacity(isDark ? 0.35 : 0.25);
        text = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        break;
      case ModiriBadgeVariant.emerald:
        bg = const Color(0xFF10B981).withOpacity(isDark ? 0.20 : 0.10);
        border = const Color(0xFF10B981).withOpacity(isDark ? 0.35 : 0.25);
        text = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
        break;
      case ModiriBadgeVariant.amber:
        bg = ModiriColors.brandAmber.withOpacity(isDark ? 0.20 : 0.10);
        border = ModiriColors.brandAmber.withOpacity(isDark ? 0.35 : 0.25);
        text = isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309);
        break;
      case ModiriBadgeVariant.rose:
        bg = ModiriColors.brandRose.withOpacity(isDark ? 0.20 : 0.10);
        border = ModiriColors.brandRose.withOpacity(isDark ? 0.35 : 0.25);
        text = isDark ? const Color(0xFFFDA4AF) : const Color(0xFFBE123C);
        break;
      case ModiriBadgeVariant.violet:
        bg = ModiriColors.brandViolet.withOpacity(isDark ? 0.20 : 0.10);
        border = ModiriColors.brandViolet.withOpacity(isDark ? 0.35 : 0.25);
        text = isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9);
        break;
      case ModiriBadgeVariant.neutral:
        bg = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);
        border = isDark ? ModiriColors.lineDark : ModiriColors.lineLight;
        text = isDark ? ModiriColors.textDarkSecondary : ModiriColors.textLightSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(isPill ? 20 : 6),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: text),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: text,
            ),
          ),
        ],
      ),
    );
  }
}
