import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Segmented pill tabs with a sliding highlight.
class PillTabs extends StatefulWidget {
  const PillTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  State<PillTabs> createState() => _PillTabsState();
}

class _PillTabsState extends State<PillTabs> {
  List<GlobalKey> _keys = [];
  List<double> _lefts = [];
  List<double> _widths = [];

  @override
  void initState() {
    super.initState();
    _keys = List.generate(
      widget.labels.length,
      (_) => GlobalKey(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant PillTabs oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.labels.length != widget.labels.length) {
      _keys = List.generate(
        widget.labels.length,
        (_) => GlobalKey(),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final trackBox = context.findRenderObject() as RenderBox?;

    if (trackBox == null || !trackBox.attached) return;

    final lefts = <double>[];
    final widths = <double>[];

    for (final key in _keys) {
      final itemBox = key.currentContext?.findRenderObject() as RenderBox?;

      if (itemBox == null) {
        lefts.add(0);
        widths.add(0);
        continue;
      }

      final offset = itemBox.localToGlobal(Offset.zero, ancestor: trackBox);

      lefts.add(offset.dx);
      widths.add(itemBox.size.width);
    }

    if (!mounted) return;

    setState(() {
      _lefts = lefts;
      _widths = widths;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready = _widths.length == widget.labels.length && _widths.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0F8),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Stack(
        children: [
          if (ready)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              left: _lefts[widget.selectedIndex],
              width: _widths[widget.selectedIndex],
              top: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.labels.length; i++)
                GestureDetector(
                  key: _keys[i],
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onChanged(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 350),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: i == widget.selectedIndex
                            ? Colors.white
                            : AppColors.textSecondaryLight,
                      ),
                      child: Text(widget.labels[i]),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
