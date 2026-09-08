import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Data for a single nav destination.
class PillNavItem {
  const PillNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Futuristic bottom navigation bar.
///
/// The four original navigation destinations remain:
/// Dashboard / Sales / Inventory / More.
///
/// AI Assistant is a special center action and is NOT treated as a fifth
/// navigation tab, so the original tab indexes and orb behavior remain intact.
class FuturisticNavBar extends StatefulWidget {
  const FuturisticNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.onAiAssistant,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<PillNavItem> items;
  final VoidCallback onAiAssistant;

  @override
  State<FuturisticNavBar> createState() => _FuturisticNavBarState();
}

enum _FnbIconType { home, pos, storage, more }

class _FuturisticNavBarState extends State<FuturisticNavBar>
    with TickerProviderStateMixin {
  static const _travelMs = 460;
  static const _pressMs = 150;
  static const _trailMs = 520;
  static const _breatheMs = 3200;
  static const _pulseMs = 2600;

  final _barKey = GlobalKey();
  final List<GlobalKey> _itemKeys = [];

  late final AnimationController _travelCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _travelMs),
  );

  late final AnimationController _breatheCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _breatheMs),
  )..repeat(reverse: true);

  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _pulseMs),
  )..repeat(reverse: true);

  double _startX = 0;
  double _startSize = 56;
  double _endX = 0;
  double _endSize = 56;

  double _orbX = 0;
  double _orbSize = 56;

  double _scaleX = 1;
  double _scaleY = 1;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _placeInitial();
    });
  }

  @override
  void didUpdateWidget(covariant FuturisticNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.currentIndex != oldWidget.currentIndex &&
        widget.currentIndex != _active) {
      _travelTo(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _travelCtrl.dispose();
    _breatheCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  ({double x, double size})? _measure(int index) {
    if (index < 0 || index >= _itemKeys.length) {
      return null;
    }

    final barBox =
        _barKey.currentContext?.findRenderObject() as RenderBox?;

    final elBox =
        _itemKeys[index].currentContext?.findRenderObject() as RenderBox?;

    if (barBox == null ||
        elBox == null ||
        !barBox.attached ||
        !elBox.attached) {
      return null;
    }

    final barTopLeft = barBox.localToGlobal(Offset.zero);
    final elTopLeft = elBox.localToGlobal(Offset.zero);
    final elSize = elBox.size;

    const size = 58.0;

    final centerX =
        (elTopLeft.dx - barTopLeft.dx) + (elSize.width / 2);

    return (
      x: centerX - size / 2 - 14.0,
      size: size,
    );
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

    final size = _lerp(
      _startSize,
      _endSize,
      math.min(1.0, raw * 1.4),
    );

    final bulge =
        math.sin(math.min(1.0, raw) * math.pi) * 0.22;

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

  static double _easeOutBack(
    double t, [
    double overshoot = 1.28,
  ]) {
    final c1 = overshoot;
    final c3 = c1 + 1;

    return 1 +
        c3 * math.pow(t - 1, 3).toDouble() +
        c1 * math.pow(t - 1, 2).toDouble();
  }

  static double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  void _repositionAfterResize() {
    final m = _measure(_active);

    if (m != null && mounted && !_travelCtrl.isAnimating) {
      setState(() {
        _orbX = m.x;
        _orbSize = m.size;
      });
    }
  }

  static const _iconTypes = [
    _FnbIconType.home,
    _FnbIconType.pos,
    _FnbIconType.storage,
    _FnbIconType.more,
  ];

  static const _iconSizes = [
    26.0,
    30.0,
    30.0,
    26.0,
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 9),
      child: SizedBox(
        height: 70,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (_lastWidth != constraints.maxWidth) {
              _lastWidth = constraints.maxWidth;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _repositionAfterResize();
              });
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
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment(-0.6, -1),
              end: Alignment(0.6, 1),
              colors: [
                Color(0xFF131B4D),
                Color(0xFF0B1442),
                Color(0xFF07103A),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
            border: Border.all(
              color: const Color(0x597A6EFF),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0x472D3CB4),
                blurRadius: 60,
                offset: const Offset(0, 25),
              ),
              BoxShadow(
                color: const Color(0x474369FF),
                blurRadius: 35,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.10),
                blurRadius: 8,
                spreadRadius: -6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                if (_ready)
                  _TrailBlob(
                    key: ValueKey(_trailKey),
                    x: _startX,
                    size: _startSize,
                    durationMs: _trailMs,
                  ),
                if (_ready)
                  AnimatedBuilder(
                    animation: _breatheCtrl,
                    builder: (context, _) {
                      final breathe =
                          _travelCtrl.isAnimating
                              ? 0.0
                              : _breatheCtrl.value;

                      return Positioned(
                        left: _orbX,
                        top: 35 - _orbSize / 2,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..scale(_scaleX, _scaleY),
                          child: _Orb(
                            size: _orbSize,
                            breathe: breathe,
                            traveling: _travelCtrl.isAnimating,
                          ),
                        ),
                      );
                    },
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildItem(0),
                    _buildItem(1),
                    _buildAiItem(),
                    _buildItem(2),
                    _buildItem(3),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int i) {
    final item = widget.items[i];

    final isActive = _active == i;
    final isPressed = _pressedIndex == i;

    final iconType =
        i < _iconTypes.length
            ? _iconTypes[i]
            : _FnbIconType.more;

    final iconSize =
        i < _iconSizes.length
            ? _iconSizes[i]
            : 26.0;

    final scale =
        isPressed
            ? 0.96
            : (isActive ? 1.1 : 1.0);

    return Tooltip(
      message: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (i != _active) {
            _travelTo(i);
            widget.onTap(i);
          }
        },
        onTapDown: (_) {
          setState(() => _pressedIndex = i);
        },
        onTapUp: (_) {
          setState(() => _pressedIndex = null);
        },
        onTapCancel: () {
          setState(() => _pressedIndex = null);
        },
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          padding: const EdgeInsets.all(14),
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, _) {
              return AnimatedScale(
                scale: scale,
                duration: const Duration(
                  milliseconds: _pressMs,
                ),
                curve: Curves.easeOutCubic,
                child: SizedBox(
                  key: _itemKeys[i],
                  width: iconSize,
                  height: iconSize,
                  child: CustomPaint(
                    painter: _FnbIconPainter(
                      type: iconType,
                      active: isActive,
                      glow: isActive
                          ? _pulseCtrl.value
                          : 0,
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

  Widget _buildAiItem() {
    return Tooltip(
      message: 'AI Assistant',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onAiAssistant,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 54,
            minHeight: 54,
          ),
          padding: const EdgeInsets.all(8),
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, _) {
              final pulse =
                  1.0 + (_pulseCtrl.value * 0.06);

              return Transform.scale(
                scale: pulse,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,

                    // Refined premium glassmorphism:
                    // dark blue-violet surface with a soft cool
                    // highlight instead of the previous neon look.
                    gradient: const RadialGradient(
                      center: Alignment(-0.28, -0.34),
                      radius: 0.95,
                      colors: [
                        Color(0xFF6F86B8),
                        Color(0xFF405784),
                        Color(0xFF2B386A),
                        Color(0xFF1A2148),
                      ],
                      stops: [
                        0.0,
                        0.32,
                        0.68,
                        1.0,
                      ],
                    ),

                    // Thin, subtle glass edge.
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: 0.28,
                      ),
                      width: 1.0,
                    ),

                    // Close, restrained ambient lighting.
                    // No large neon halo.
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x454F6FFF),
                        blurRadius:
                            9 + (_pulseCtrl.value * 3),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.22,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.smart_toy_outlined,
                    color: Colors.white,
                    size: 27,
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

/// Simple moving navigation indicator.
class _Orb extends StatelessWidget {
  const _Orb({
    required this.size,
    required this.breathe,
    required this.traveling,
  });

  final double size;
  final double breathe;
  final bool traveling;

  @override
  Widget build(BuildContext context) {
    final brightness =
        traveling
            ? 1.0
            : _lerpD(0.94, 1.0, breathe);

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,

          // Simple dark navy surface that blends
          // naturally with the navigation bar.
          gradient: RadialGradient(
            center: const Alignment(-0.30, -0.35),
            radius: 0.95,
            colors: [
              Color(0xFF3A4668).withValues(
                alpha: (0.95 * brightness)
                    .clamp(0, 1.0)
                    .toDouble(),
              ),
              const Color(0xFF283452),
              const Color(0xFF182344),
              const Color(0xFF101A3B),
            ],
            stops: const [
              0.0,
              0.38,
              0.72,
              1.0,
            ],
          ),

          // Very subtle edge.
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.0,
          ),

          // No neon glow.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }

  double _lerpD(double a, double b, double t) {
    return a + (b - a) * t;
  }
}

/// Simple, subtle trail for the moving navigation indicator.
class _TrailBlob extends StatefulWidget {
  const _TrailBlob({
    super.key,
    required this.x,
    required this.size,
    required this.durationMs,
  });

  final double x;
  final double size;
  final int durationMs;

  @override
  State<_TrailBlob> createState() => _TrailBlobState();
}

class _TrailBlobState extends State<_TrailBlob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: widget.durationMs,
        ),
      )..forward();

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

        final opacity = 0.18 * (1 - t);
        final scale = 1 + 0.12 * t;

        return Positioned(
          left: widget.x,
          top: 35 - widget.size / 2,
          child: Opacity(
            opacity: opacity.clamp(0, 1).toDouble(),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF263452),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws the four original bespoke nav icons.
class _FnbIconPainter extends CustomPainter {
  _FnbIconPainter({
    required this.type,
    required this.active,
    required this.glow,
  });

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
        ..color = Color.lerp(
          const Color(0x9945B8FF),
          const Color(0xE645B8FF),
          glow,
        )!
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          6 + glow * 4,
        );

      canvas.saveLayer(
        Offset.zero & size,
        Paint(),
      );

      _drawShape(
        canvas,
        size,
        glowPaint..style = PaintingStyle.stroke,
      );

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
        _paintStorage(
          canvas,
          size,
          paint,
          fillPaint,
          opacity,
        );
        break;

      case _FnbIconType.more:
        _paintMore(canvas, size, fillPaint);
        break;
    }
  }

  void _drawShape(
    Canvas canvas,
    Size size,
    Paint paint,
  ) {
    final fill = Paint()..color = paint.color;

    switch (type) {
      case _FnbIconType.home:
        _paintHome(canvas, size, paint, fill);
        break;

      case _FnbIconType.pos:
        _paintPos(canvas, size, paint, fill);
        break;

      case _FnbIconType.storage:
        _paintStorage(
          canvas,
          size,
          paint,
          fill,
          1,
        );
        break;

      case _FnbIconType.more:
        _paintMore(canvas, size, fill);
        break;
    }
  }

  void _paintHome(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fill,
  ) {
    final s = size.width / 72;

    stroke.strokeWidth = 5.5 * s;

    final rect = Rect.fromLTWH(
      19 * s,
      7 * s,
      34 * s,
      58 * s,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(10 * s),
      ),
      stroke,
    );

    canvas.drawCircle(
      Offset(36 * s, 55 * s),
      3.2 * s,
      fill,
    );
  }

  void _paintPos(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fill,
  ) {
    final s = size.width / 82;

    stroke.strokeWidth = 5 * s;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          27 * s,
          6 * s,
          28 * s,
          13 * s,
        ),
        Radius.circular(5 * s),
      ),
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
      Offset(27 * s, 32 * s),
      Offset(41 * s, 32 * s),
      Offset(55 * s, 32 * s),
      Offset(27 * s, 42 * s),
      Offset(41 * s, 42 * s),
      Offset(55 * s, 42 * s),
    ]) {
      canvas.drawCircle(
        p,
        3 * s,
        fill,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          11 * s,
          49 * s,
          60 * s,
          20 * s,
        ),
        Radius.circular(7 * s),
      ),
      stroke,
    );

    final line = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.5 * s;

    canvas.drawLine(
      Offset(30 * s, 60 * s),
      Offset(52 * s, 60 * s),
      line,
    );
  }

  void _paintStorage(
    Canvas canvas,
    Size size,
    Paint stroke,
    Paint fill,
    double opacity,
  ) {
    final s = size.width / 82;

    stroke.strokeWidth = 5 * s;

    final divider = Paint()
      ..color = const Color(0xFF4778FF).withValues(
        alpha: opacity.clamp(0.35, 1).toDouble(),
      )
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 9 * s;

    canvas.drawLine(
      Offset(41 * s, 17 * s),
      Offset(41 * s, 50 * s),
      divider,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          12 * s,
          22 * s,
          58 * s,
          49 * s,
        ),
        Radius.circular(9 * s),
      ),
      stroke,
    );

    final flap = Path()
      ..moveTo(12 * s, 29 * s)
      ..cubicTo(
        12 * s,
        22 * s,
        17 * s,
        17 * s,
        24 * s,
        17 * s,
      )
      ..lineTo(58 * s, 17 * s)
      ..cubicTo(
        65 * s,
        17 * s,
        70 * s,
        22 * s,
        70 * s,
        29 * s,
      );

    canvas.drawPath(flap, stroke);

    final line = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5 * s;

    canvas.drawLine(
      Offset(32 * s, 47 * s),
      Offset(51 * s, 47 * s),
      line,
    );
  }

  void _paintMore(
    Canvas canvas,
    Size size,
    Paint fill,
  ) {
    final s = size.width / 72;

    for (final cx in [18, 36, 54]) {
      canvas.drawCircle(
        Offset(cx * s, 36 * s),
        6 * s,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _FnbIconPainter oldDelegate,
  ) {
    return oldDelegate.active != active ||
        oldDelegate.glow != glow ||
        oldDelegate.type != type;
  }
}