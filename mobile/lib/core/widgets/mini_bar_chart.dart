import 'dart:async';
import 'package:flutter/material.dart';

/// A small set of gradient bars that grow in from zero, staggered by
/// index  -  matches the reference `.bars`/`.bars i` CSS exactly:
/// 5px gap, 44px default height, top-rounded (5px) / bottom-barely-
/// rounded (2px) corners, and a fixed `linear-gradient(180deg,#8fa0fb,
/// #3d55f5)` fill (not a computed tint) so the color is pixel-identical
/// to the web reference, not just "close".
///
/// [values] should already be normalized to 0..1 (fraction of the
/// tallest bar); pass real, computed data  -  never invented figures.
class MiniBarChart extends StatefulWidget {
  const MiniBarChart({
    super.key,
    required this.values,
    this.height = 44,
    this.gap = 5,
    this.staggerMs = 90,
    this.gradientTop = const Color(0xFF8FA0FB),
    this.gradientBottom = const Color(0xFF3D55F5),
  });

  final List<double> values;
  final double height;
  final double gap;
  final int staggerMs;
  final Color gradientTop;
  final Color gradientBottom;

  @override
  State<MiniBarChart> createState() => _MiniBarChartState();
}

class _MiniBarChartState extends State<MiniBarChart> {
  bool _grown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _grown = true);
    });
  }

  @override
  void didUpdateWidget(covariant MiniBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values) {
      // Data changed (e.g. Reports period switch)  -  replay the grow-in,
      // matching the reference's tab-switch bar re-animation.
      setState(() => _grown = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _grown = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) {
      return SizedBox(height: widget.height);
    }
    return SizedBox(
      height: widget.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < widget.values.length; i++) ...[
            if (i > 0) SizedBox(width: widget.gap),
            Expanded(
              child: _DelayedBar(
                delay: Duration(milliseconds: widget.staggerMs * i),
                fraction: _grown ? widget.values[i].clamp(0.0, 1.0) : 0.0,
                maxHeight: widget.height,
                gradientTop: widget.gradientTop,
                gradientBottom: widget.gradientBottom,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DelayedBar extends StatefulWidget {
  const _DelayedBar({
    required this.delay,
    required this.fraction,
    required this.maxHeight,
    required this.gradientTop,
    required this.gradientBottom,
  });

  final Duration delay;
  final double fraction;
  final double maxHeight;
  final Color gradientTop;
  final Color gradientBottom;

  @override
  State<_DelayedBar> createState() => _DelayedBarState();
}

class _DelayedBarState extends State<_DelayedBar> {
  double _target = 0;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _DelayedBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fraction != widget.fraction) _schedule();
  }

  Timer? _timer;

  void _schedule() {
    _timer?.cancel();
    if (widget.fraction == 0) {
      setState(() => _target = 0);
      return;
    }
    if (widget.delay == Duration.zero) {
      setState(() => _target = widget.fraction);
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) setState(() => _target = widget.fraction);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      height: (_target.clamp(0.0, 1.0)) * widget.maxHeight,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(5),
          topRight: Radius.circular(5),
          bottomLeft: Radius.circular(2),
          bottomRight: Radius.circular(2),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [widget.gradientTop, widget.gradientBottom],
        ),
      ),
    );
  }
}
