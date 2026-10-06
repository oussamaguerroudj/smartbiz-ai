import 'dart:async';
import 'package:flutter/material.dart';

/// Fades and slides its child up into place once, on first build (or
/// after [delay]). Used to give list rows and cards a gentle staggered
/// entrance instead of popping in — motion that answers the screen
/// appearing, played once, not looped.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
    this.offset = 14,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - _fade.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Convenience helper: wraps each item of a list with [FadeSlideIn],
/// staggering the delay by index so rows cascade in rather than all
/// appearing at once.
extension StaggeredList on List<Widget> {
  List<Widget> staggered({Duration step = const Duration(milliseconds: 45)}) {
    return [
      for (var i = 0; i < length; i++)
        FadeSlideIn(delay: step * i, child: this[i]),
    ];
  }
}
