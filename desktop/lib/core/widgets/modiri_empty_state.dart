import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ModiriEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  const ModiriEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark ? ModiriColors.ink850 : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? ModiriColors.lineDark : ModiriColors.lineLight,
                ),
              ),
              child: Icon(
                icon,
                size: 28,
                color: isDark ? ModiriColors.textDarkMuted : ModiriColors.textLightMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : ModiriColors.textLightPrimary,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? ModiriColors.textDarkSecondary : ModiriColors.textLightSecondary,
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
