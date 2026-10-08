import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Data for a single nav destination. Kept API-compatible with the old
/// `PillNavItem` (icon/activeIcon/label) so this is a drop-in swap in
/// `main_shell.dart`  -  the Material `icon`/`activeIcon` are only used as
/// a fallback if more than 4 items are supplied; for the standard 4-tab
/// layout the bespoke icons below (matching the approved Futuristic Nav
/// spec: Home/POS/Storage/More) are drawn instead.
class PillNavItem {
  const PillNavItem({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Flutter port of `FuturisticNavBar.jsx`: a dark glass pill with a
/// glowing orb that glides beneath the active tab, squash/stretch on
/// arrival, a fading trail, a slow sheen sweep across the glass, and a
/// neon breathing pulse on the active icon.
class FuturisticNavBar extends StatefulWidget {
  const FuturisticNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<PillNavItem> items;

  @override
  State<FuturisticNavBar> createState() => _FuturisticNavBarState();
}

enum _FnbIconType { home, pos, storage, more }

class _FuturisticNavBarState extends State<FuturisticNavBar> with TickerProviderStateMixin {
  static const _travelMs = 460;
  static const _pressMs = 150;
  static const _trailMs = 520;
  static const _sheenMs = 7000;
  static const _breatheMs = 3200;
  static const _pulseMs = 2600;

  final _barKey = GlobalKey();
  final List<GlobalKey> _itemKeys = [];

  late final AnimationController _travelCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: _travelMs));
  late final AnimationController _sheenCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: _sheenMs))..repeat();
  late final AnimationController _breatheCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: _breatheMs))..repeat(reverse: true);
  late final AnimationController _pulseCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: _pulseMs))..repeat(reverse: true);

  double _startX = 0, _startSize = 56, _endX = 0, _endSize = 56;
  double _orbX = 0, _orbSize = 56;
  double _scaleX = 1, _scaleY = 1;
  bool _ready = false;
  int _trailKey = 0;
  int? _pressedIndex;
  late int _active = widget.currentIndex;
  double? _lastWidth;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.items.length; i++) {
      _itemKeys.add(GlobalKey());
    }
    _travelCtrl.addListener(_onTravelTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _placeInitial());
  }

  @override
  void didUpdateWidget(covariant FuturisticNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex && widget.currentIndex != _active) {
      _travelTo(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _travelCtrl.dispose();
    _sheenCtrl.dispose();
    _breatheCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  ({double x, double size})? _measure(int index) {
    final barBox = _barKey.currentContext?.findRenderObject() as RenderBox?;
    final elBox = _itemKeys[index].currentContext?.findRenderObject() as RenderBox?;
    if (barBox == null || elBox == null || !barBox.attached || !elBox.attached) return null;
    final barTopLeft = barBox.localToGlobal(Offset.zero);
    final elTopLeft = elBox.localToGlobal(Offset.zero);
    final elSize = elBox.size;
    final size = math.min(math.min(elSize.width, elSize.height), 64.0) + 14.0;
    final centerX = (elTopLeft.dx - barTopLeft.dx) + elSize.width / 2;
    return (x: centerX - size / 2, size: size);
  }

  void _placeInitial() {
    final m = _measure(_active);
    if (m == null) return;
    setState(() {
      _orbX = m.x;
      _orbSize = m.size;
      _startX = m.x;
      _startSize = m.size;
      _endX = m.x;
      _endSize = m.size;
      _ready = true;
    });
  }

  void _travelTo(int index) {
    if (index == _active || _travelCtrl.isAnimating) return;
    final target = _measure(index);
    if (target == null) return;

    _startX = _orbX;
    _startSize = _orbSize;
    _endX = target.x;
    _endSize = target.size;

    setState(() {
      _active = index;
      _trailKey++;
    });

    _travelCtrl
      ..reset()
      ..forward();
  }

  void _onTravelTick() {
    final raw = _travelCtrl.value;
    final eased = _easeOutBack(raw, 1.05);
    final x = _lerp(_startX, _endX, eased);
    final size = _lerp(_startSize, _endSize, math.min(1.0, raw * 1.4));
    final bulge = math.sin(math.min(1.0, raw) * math.pi) * 0.22;

    setState(() {
      _orbX = x;
      _orbSize = size;
      _scaleX = 1 + bulge;
      _scaleY = 1 - bulge * 0.45;
    });

    if (raw >= 1) {
      setState(() {
        _orbX = _endX;
        _orbSize = _endSize;
        _scaleX = 1;
        _scaleY = 1;
      });
    }
  }

  static double _easeOutBack(double t, [double overshoot = 1.28]) {
    final c1 = overshoot;
    final c3 = c1 + 1;
    return 1 + c3 * math.pow(t - 1, 3).toDouble() + c1 * math.pow(t - 1, 2).toDouble();
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  void _repositionAfterResize() {
    final m = _measure(_active);
    if (m != null && mounted && !_travelCtrl.isAnimating) {
      setState(() {
        _orbX = m.x;
        _orbSize = m.size;
      });
    }
  }

  static const _iconTypes = [_FnbIconType.home, _FnbIconType.pos, _FnbIconType.storage, _FnbIconType.more];
  static const _iconSizes = [26.0, 30.0, 30.0, 26.0];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 9),
      child: SizedBox(
        height: 84,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (_lastWidth != constraints.maxWidth) {
              _lastWidth = constraints.maxWidth;
              WidgetsBinding.instance.addPostFrameCallback((_) => _repositionAfterResize());
            }
            return _buildBar(context);
          },
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              key: _barKey,
              height: 84,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  begin: Alignment(-0.6, -1),
                  end: Alignment(0.6, 1),
                  colors: [Color(0xFF131B4D), Color(0xFF0B1442), Color(0xFF07103A)],
                  stops: [0.0, 0.45, 1.0],
                ),
                border: Border.all(color: const Color(0x597A6EFF)),
                boxShadow: [
                  BoxShadow(color: const Color(0x472D3CB4), blurRadius: 60, offset: const Offset(0, 25)),
                  BoxShadow(color: const Color(0x474369FF), blurRadius: 35),
                  BoxShadow(color: Colors.white.withValues(alpha: 0.10), blurRadius: 8, spreadRadius: -6, offset: const Offset(0, 2)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    // Slow diagonal sheen sweep across the glass.
                    AnimatedBuilder(
                      animation: _sheenCtrl,
                      builder: (context, _) {
                        final t = _sheenSweep(_sheenCtrl.value);
                        return Positioned.fill(
                          child: FractionalTranslation(
                            translation: Offset(t, 0),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: const Alignment(-1, -0.3),
                                  end: const Alignment(1, 0.3),
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.08),
                                    Colors.white.withValues(alpha: 0.16),
                                    Colors.white.withValues(alpha: 0.08),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                  stops: const [0.30, 0.45, 0.50, 0.55, 0.70],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Fading trail left behind at the departure point.
                    if (_ready)
                      _TrailBlob(key: ValueKey(_trailKey), x: _startX, size: _startSize, durationMs: _trailMs),

                    // The glowing orb itself.
                    if (_ready)
                      AnimatedBuilder(
                        animation: _breatheCtrl,
                        builder: (context, _) {
                          final breathe = _travelCtrl.isAnimating ? 0.0 : _breatheCtrl.value;
                          return Positioned(
                            left: _orbX,
                            top: 42 - _orbSize / 2,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..scale(_scaleX, _scaleY),
                              child: _Orb(size: _orbSize, breathe: breathe, traveling: _travelCtrl.isAnimating),
                            ),
                          );
                        },
                      ),

                    // Tab buttons.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (var i = 0; i < widget.items.length; i++)
                          _buildItem(i),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }

  double _sheenSweep(double t) {
    // 0% -> 120%, 50% -> -20%, 100% -> 120% (of own width), matching the
    // JS keyframes' background-position sweep, expressed as a fraction
    // translation via FractionalTranslation.
    if (t < 0.5) {
      final local = t / 0.5;
      return _lerp(1.2, -0.2, local);
    } else {
      final local = (t - 0.5) / 0.5;
      return _lerp(-0.2, 1.2, local);
    }
  }

  Widget _buildItem(int i) {
    final item = widget.items[i];
    final isActive = _active == i;
    final isPressed = _pressedIndex == i;
    final iconType = i < _iconTypes.length ? _iconTypes[i] : _FnbIconType.more;
    final iconSize = i < _iconSizes.length ? _iconSizes[i] : 26.0;

    final scale = isPressed ? 0.96 : (isActive ? 1.1 : 1.0);
    final translateY = isActive ? -3.0 : 0.0;

    return Tooltip(
      message: item.label,
      child: GestureDetector(
        key: _itemKeys[i],
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (i != _active) {
            _travelTo(i);
            widget.onTap(i);
          }
        },
        onTapDown: (_) => setState(() => _pressedIndex = i),
        onTapUp: (_) => setState(() => _pressedIndex = null),
        onTapCancel: () => setState(() => _pressedIndex = null),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.all(14),
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, _) {
              return AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: _pressMs),
                curve: Curves.easeOutCubic,
                child: Transform.translate(
                  offset: Offset(0, translateY),
                  child: SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CustomPaint(
                      painter: _FnbIconPainter(
                        type: iconType,
                        active: isActive,
                        glow: isActive ? _pulseCtrl.value : 0,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The glowing orb: layered radial gradient core + soft outer glow +
/// thin bright rim, with a gentle breathing brightness shift when idle.
class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.breathe, required this.traveling});
  final double size;
  final double breathe;
  final bool traveling;

  @override
  Widget build(BuildContext context) {
    final brightness = traveling ? 1.25 : _lerpD(1.0, 1.12, breathe);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0x8C45DFFF), blurRadius: 24),
                BoxShadow(color: const Color(0x8C7047FF), blurRadius: 46),
                BoxShadow(color: const Color(0x66A33CFF), blurRadius: 70),
              ],
              gradient: RadialGradient(
                center: const Alignment(-0.36, -0.44),
                radius: 0.9,
                colors: [
                  Colors.white.withValues(alpha: (0.95 * brightness).clamp(0, 1.0).toDouble()),
                  const Color(0x8CC8E6FF),
                  const Color(0x8C45DFFF),
                  const Color(0xA6357DFF),
                  const Color(0xBF7047FF),
                  const Color(0xE60B1442),
                ],
                stops: const [0.0, 0.10, 0.24, 0.50, 0.74, 1.0],
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: 14)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _lerpD(double a, double b, double t) => a + (b - a) * t;
}

/// The soft blob left at the departure point that scales up and fades
/// out once, matching the JS `fnb-trail-fade` keyframes.
class _TrailBlob extends StatefulWidget {
  const _TrailBlob({super.key, required this.x, required this.size, required this.durationMs});
  final double x;
  final double size;
  final int durationMs;

  @override
  State<_TrailBlob> createState() => _TrailBlobState();
}

class _TrailBlobState extends State<_TrailBlob> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: Duration(milliseconds: widget.durationMs))..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final opacity = 0.55 * (1 - t);
        final scale = 1 + 0.35 * t;
        return Positioned(
          left: widget.x,
          top: 42 - widget.size / 2,
          child: Opacity(
            opacity: opacity.clamp(0, 1).toDouble(),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0x807047FF),
                      const Color(0x4045DFFF),
                      const Color(0x0045DFFF),
                    ],
                    stops: const [0.0, 0.55, 0.75],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws the four bespoke nav icons (phone/home, POS terminal, storage
/// package, "more" dots) tracing the same paths as the original SVGs,
/// scaled to whatever box they're given. `glow` (0..1, only used when
/// [active]) pulses a soft neon shadow behind the strokes.
class _FnbIconPainter extends CustomPainter {
  _FnbIconPainter({required this.type, required this.active, required this.glow});

  final _FnbIconType type;
  final bool active;
  final double glow;

  static const _color = Color(0xFFF8FAFF);

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = active ? 1.0 : 0.58;
    final paintColor = _color.withValues(alpha: opacity);

    if (active) {
      final glowPaint = Paint()
        ..color = Color.lerp(const Color(0x9945B8FF), const Color(0xE645B8FF), glow)!
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + glow * 4);
      canvas.saveLayer(Offset.zero & size, Paint());
      _drawShape(canvas, size, glowPaint..style = PaintingStyle.stroke);
      canvas.restore();
    }

    final paint = Paint()
      ..color = paintColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()..color = paintColor;

    switch (type) {
      case _FnbIconType.home:
        _paintHome(canvas, size, paint, fillPaint);
        break;
      case _FnbIconType.pos:
        _paintPos(canvas, size, paint, fillPaint);
        break;
      case _FnbIconType.storage:
        _paintStorage(canvas, size, paint, fillPaint, opacity);
        break;
      case _FnbIconType.more:
        _paintMore(canvas, size, fillPaint);
        break;
    }
  }

  void _drawShape(Canvas canvas, Size size, Paint paint) {
    final fill = Paint()..color = paint.color;
    switch (type) {
      case _FnbIconType.home:
        _paintHome(canvas, size, paint, fill);
        break;
      case _FnbIconType.pos:
        _paintPos(canvas, size, paint, fill);
        break;
      case _FnbIconType.storage:
        _paintStorage(canvas, size, paint, fill, 1);
        break;
      case _FnbIconType.more:
        _paintMore(canvas, size, fill);
        break;
    }
  }

  // viewBox 72x72
  void _paintHome(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final s = size.width / 72;
    stroke.strokeWidth = 5.5 * s;
    final rect = Rect.fromLTWH(19 * s, 7 * s, 34 * s, 58 * s);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(10 * s)), stroke);
    canvas.drawCircle(Offset(36 * s, 55 * s), 3.2 * s, fill);
  }

  // viewBox 82x82
  void _paintPos(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final s = size.width / 82;
    stroke.strokeWidth = 5 * s;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(27 * s, 6 * s, 28 * s, 13 * s), Radius.circular(5 * s)),
      stroke,
    );
    final body = Path()
      ..moveTo(20 * s, 24 * s)
      ..lineTo(62 * s, 24 * s)
      ..lineTo(69 * s, 48 * s)
      ..lineTo(13 * s, 48 * s)
      ..close();
    canvas.drawPath(body, stroke);
    for (final p in [
      Offset(27 * s, 32 * s), Offset(41 * s, 32 * s), Offset(55 * s, 32 * s),
      Offset(27 * s, 42 * s), Offset(41 * s, 42 * s), Offset(55 * s, 42 * s),
    ]) {
      canvas.drawCircle(p, 3 * s, fill);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(11 * s, 49 * s, 60 * s, 20 * s), Radius.circular(7 * s)),
      stroke,
    );
    final line = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.5 * s;
    canvas.drawLine(Offset(30 * s, 60 * s), Offset(52 * s, 60 * s), line);
  }

  // viewBox 82x82
  void _paintStorage(Canvas canvas, Size size, Paint stroke, Paint fill, double opacity) {
    final s = size.width / 82;
    stroke.strokeWidth = 5 * s;

    // The divider line is fixed brand-blue in the original spec,
    // regardless of active/inactive state.
    final divider = Paint()
      ..color = const Color(0xFF4778FF).withValues(alpha: opacity.clamp(0.35, 1).toDouble())
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 9 * s;
    canvas.drawLine(Offset(41 * s, 17 * s), Offset(41 * s, 50 * s), divider);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(12 * s, 22 * s, 58 * s, 49 * s), Radius.circular(9 * s)),
      stroke,
    );

    final flap = Path()
      ..moveTo(12 * s, 29 * s)
      ..cubicTo(12 * s, 22 * s, 17 * s, 17 * s, 24 * s, 17 * s)
      ..lineTo(58 * s, 17 * s)
      ..cubicTo(65 * s, 17 * s, 70 * s, 22 * s, 70 * s, 29 * s);
    canvas.drawPath(flap, stroke);

    final line = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5 * s;
    canvas.drawLine(Offset(32 * s, 47 * s), Offset(51 * s, 47 * s), line);
  }

  // viewBox 72x72
  void _paintMore(Canvas canvas, Size size, Paint fill) {
    final s = size.width / 72;
    for (final cx in [18, 36, 54]) {
      canvas.drawCircle(Offset(cx * s, 36 * s), 6 * s, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _FnbIconPainter oldDelegate) =>
      oldDelegate.active != active || oldDelegate.glow != glow || oldDelegate.type != type;
}
