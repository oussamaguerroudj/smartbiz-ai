import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum PillTone { brand, danger, neutral }

/// Small rounded status label  -  "Paid" / "Present" / "Scheduled" / "Done"  - 
/// matching the badge treatment in the approved redesign. [pulse] adds a
/// subtle glowing dot for "live" statuses (present, scheduled, in stock)
/// so the eye is drawn to state that can change, without animating text
/// that can't.
class StatusPill extends StatefulWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = PillTone.brand,
    this.pulse = false,
  });

  final String label;
  final PillTone tone;
  final bool pulse;

  @override
  State<StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<StatusPill> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  (Color bg, Color fg) get _colors {
    switch (widget.tone) {
      case PillTone.brand:
        return (AppColors.primary.withValues(alpha: 0.12), AppColors.primaryDark);
      case PillTone.danger:
        return (AppColors.danger.withValues(alpha: 0.14), const Color(0xFFA8371F));
      case PillTone.neutral:
        return (const Color(0xFFEEF0F8), AppColors.textSecondaryLight);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.pulse) ...[
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                // Reproduces the reference's exact keyframes:
                // 0%   spread 0,  alpha .45
                // 70%  spread 5,  alpha 0
                // 100% spread 0,  alpha 0
                final t = _controller.value;
                double spread;
                double alpha;
                if (t <= 0.7) {
                  final p = t / 0.7;
                  spread = 5 * p;
                  alpha = 0.45 * (1 - p);
                } else {
                  final p = (t - 0.7) / 0.3;
                  spread = 5 * (1 - p);
                  alpha = 0;
                }
                return Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: fg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: fg.withValues(alpha: alpha),
                        blurRadius: 0,
                        spreadRadius: spread,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 5),
          ],
          Text(
            widget.label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}
