import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ModiriButtonVariant {
  primary,
  ghost,
  danger,
}

class ModiriButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ModiriButtonVariant variant;
  final bool isLoading;
  final double? width;
  final EdgeInsetsGeometry padding;

  const ModiriButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = ModiriButtonVariant.primary,
    this.isLoading = false,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  const ModiriButton.primary({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  }) : variant = ModiriButtonVariant.primary;

  const ModiriButton.ghost({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  }) : variant = ModiriButtonVariant.ghost;

  const ModiriButton.danger({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  }) : variant = ModiriButtonVariant.danger;

  @override
  State<ModiriButton> createState() => _ModiriButtonState();
}

class _ModiriButtonState extends State<ModiriButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    Decoration decoration;
    Color textColor;
    Color iconColor;

    switch (widget.variant) {
      case ModiriButtonVariant.primary:
        textColor = Colors.white;
        iconColor = Colors.white;
        decoration = BoxDecoration(
          gradient: ModiriColors.brandGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: ModiriColors.brandBlue.withOpacity(_isHovered ? 0.45 : 0.30),
              blurRadius: _isHovered ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        );
        break;
      case ModiriButtonVariant.ghost:
        textColor = isDark ? ModiriColors.textDarkPrimary : ModiriColors.textLightPrimary;
        iconColor = isDark ? ModiriColors.textDarkSecondary : ModiriColors.textLightSecondary;
        decoration = BoxDecoration(
          color: isDark
              ? (_isHovered ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.03))
              : (_isHovered ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? ModiriColors.lineDark : ModiriColors.lineLight,
            width: 1,
          ),
        );
        break;
      case ModiriButtonVariant.danger:
        textColor = Colors.white;
        iconColor = Colors.white;
        decoration = BoxDecoration(
          color: _isHovered ? const Color(0xFFDC2626) : ModiriColors.brandRose,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: ModiriColors.brandRose.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        );
        break;
    }

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isEnabled ? 1.0 : 0.55,
          child: Container(
            width: widget.width,
            padding: widget.padding,
            decoration: decoration,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else if (widget.icon != null) ...[
                  Icon(widget.icon, size: 16, color: iconColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
