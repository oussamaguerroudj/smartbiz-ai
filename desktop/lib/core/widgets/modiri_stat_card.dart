import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/modiri_formatters.dart';

enum StatCardTone {
  blue,
  violet,
  teal,
  amber,
  neutral,
}

class ModiriStatCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sublabel;
  final StatCardTone tone;
  final bool highlight;
  final VoidCallback? onTap;

  const ModiriStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sublabel,
    this.tone = StatCardTone.neutral,
    this.highlight = false,
    this.onTap,
  });

  @override
  State<ModiriStatCard> createState() => _ModiriStatCardState();
}

class _ModiriStatCardState extends State<ModiriStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color iconColor;
    Color iconBg;
    List<Color> gradientColors;

    switch (widget.tone) {
      case StatCardTone.blue:
        iconColor = ModiriColors.brandBlue;
        iconBg = ModiriColors.brandBlue.withOpacity(isDark ? 0.22 : 0.12);
        gradientColors = isDark
            ? [
                ModiriColors.brandBlue.withOpacity(0.18),
                ModiriColors.ink800.withOpacity(0.70),
              ]
            : [
                ModiriColors.brandBlue.withOpacity(0.08),
                Colors.white,
              ];
        break;
      case StatCardTone.violet:
        iconColor = ModiriColors.brandViolet;
        iconBg = ModiriColors.brandViolet.withOpacity(isDark ? 0.22 : 0.12);
        gradientColors = isDark
            ? [
                ModiriColors.brandViolet.withOpacity(0.18),
                ModiriColors.ink800.withOpacity(0.70),
              ]
            : [
                ModiriColors.brandViolet.withOpacity(0.08),
                Colors.white,
              ];
        break;
      case StatCardTone.teal:
        iconColor = ModiriColors.brandTeal;
        iconBg = ModiriColors.brandTeal.withOpacity(isDark ? 0.22 : 0.12);
        gradientColors = isDark
            ? [
                ModiriColors.brandTeal.withOpacity(0.18),
                ModiriColors.ink800.withOpacity(0.70),
              ]
            : [
                ModiriColors.brandTeal.withOpacity(0.08),
                Colors.white,
              ];
        break;
      case StatCardTone.amber:
        iconColor = ModiriColors.brandAmber;
        iconBg = ModiriColors.brandAmber.withOpacity(isDark ? 0.22 : 0.12);
        gradientColors = isDark
            ? [
                ModiriColors.brandAmber.withOpacity(0.18),
                ModiriColors.ink800.withOpacity(0.70),
              ]
            : [
                ModiriColors.brandAmber.withOpacity(0.08),
                Colors.white,
              ];
        break;
      case StatCardTone.neutral:
        iconColor = isDark ? ModiriColors.textDarkSecondary : ModiriColors.textLightSecondary;
        iconBg = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04);
        gradientColors = isDark
            ? [
                Colors.white.withOpacity(0.05),
                ModiriColors.ink800.withOpacity(0.70),
              ]
            : [
                const Color(0xFFF1F5F9),
                Colors.white,
              ];
        break;
    }

    Color borderColor;
    if (widget.highlight) {
      borderColor = ModiriColors.brandAmber.withOpacity(0.6);
    } else if (_isHovered) {
      borderColor = isDark ? Colors.white.withOpacity(0.2) : ModiriColors.brandBlue.withOpacity(0.4);
    } else {
      borderColor = isDark ? ModiriColors.lineDark : ModiriColors.lineLight;
    }

    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            border: Border.all(color: borderColor, width: widget.highlight ? 1.5 : 1.0),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.04),
                blurRadius: _isHovered ? 12 : 6,
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, size: 18, color: iconColor),
                  ),
                  AnimatedSlide(
                    offset: _isHovered ? Offset(isRtl ? -0.15 : 0.15, 0) : Offset.zero,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      isRtl ? Icons.chevron_left : Icons.chevron_right,
                      size: 16,
                      color: isDark ? ModiriColors.textDarkMuted : ModiriColors.textLightMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Align(
                  alignment: isRtl ? Alignment.bottomRight : Alignment.bottomLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: isDark ? ModiriColors.textDarkSecondary : ModiriColors.textLightSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                        child: Text(
                          ModiriFormatters.toLatinDigits(widget.value),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : ModiriColors.textLightPrimary,
                          ),
                        ),
                      ),
                      if (widget.sublabel != null && widget.sublabel!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.sublabel!,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.15,
                            color: isDark ? ModiriColors.textDarkMuted : ModiriColors.textLightMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
