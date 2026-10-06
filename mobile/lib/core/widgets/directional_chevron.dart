import 'package:flutter/material.dart';

/// RTL-aware forward chevron (used in ListTiles, cards, and navigation rows).
/// In LTR, points right (forward into the screen).
/// In RTL, points left (forward into the screen).
class ForwardChevron extends StatelessWidget {
  const ForwardChevron({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
      size: size,
      color: color,
    );
  }
}

/// RTL-aware previous chevron (used in date/period pickers and carousels).
/// In LTR, points left (backwards / into the past).
/// In RTL, points right (backwards / into the past).
class PreviousChevron extends StatelessWidget {
  const PreviousChevron({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      isRtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
      size: size,
      color: color,
    );
  }
}

/// RTL-aware next chevron (used in date/period pickers and carousels).
/// In LTR, points right (forward / into the future).
/// In RTL, points left (forward / into the future).
class NextChevron extends StatelessWidget {
  const NextChevron({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
      size: size,
      color: color,
    );
  }
}
