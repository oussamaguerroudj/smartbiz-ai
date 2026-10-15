import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum PillTone { brand, success, warning, danger, neutral }

/// Small rounded status label — "Paid" / "Present" / "Scheduled" / "Done" —
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
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..repeat();
    }
  }

  @override
  void didUpdateWidget(covariant StatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..repeat();
    } else if (!widget.pulse && _controller != null) {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  (Color bg, Color fg) _getColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (widget.tone) {
      case PillTone.brand:
        return isDark
            ? (AppColors.primary.withValues(alpha: 0.25), AppColors.primaryLight)
            : (AppColors.primary.withValues(alpha: 0.12), AppColors.primaryDark);
      case PillTone.success:
        return isDark
            ? (AppColors.success.withValues(alpha: 0.22), const Color(0xFF34D399))
            : (AppColors.success.withValues(alpha: 0.12), const Color(0xFF065F46));
      case PillTone.warning:
        return isDark
            ? (AppColors.warning.withValues(alpha: 0.22), const Color(0xFFFBBF24))
            : (AppColors.warning.withValues(alpha: 0.14), const Color(0xFF92400E));
      case PillTone.danger:
        return isDark
            ? (AppColors.danger.withValues(alpha: 0.25), const Color(0xFFF87171))
            : (AppColors.danger.withValues(alpha: 0.14), const Color(0xFFA8371F));
      case PillTone.neutral:
        return isDark
            ? (Colors.white.withValues(alpha: 0.1), AppColors.textSecondaryDark)
            : (const Color(0xFFEEF0F8), AppColors.textSecondaryLight);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _getColors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.pulse && _controller != null) ...[
            AnimatedBuilder(
              animation: _controller!,
              builder: (context, _) {
                // Reproduces the reference's exact keyframes:
                // 0%   spread 0,  alpha .45
                // 70%  spread 5,  alpha 0
                // 100% spread 0,  alpha 0
                final t = _controller!.value;
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
          Flexible(
            child: Text(
              widget.label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
