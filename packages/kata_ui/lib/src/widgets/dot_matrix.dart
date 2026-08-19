import 'dart:async';

import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';

/// 6×4 grid of dots that light up with progress (writing screen).
/// With [animated], the lit count walks toward the target one dot per [KataMotion.dotStep]
/// so a burst of progress still reads as a sweep.
class DotMatrixProgress extends StatefulWidget {
  const DotMatrixProgress({super.key, required this.progress, this.columns = 6, this.rows = 4, this.dot = 10, this.gap = 9, this.animated = false});
  final double progress;
  final int columns, rows;
  final double dot, gap;
  final bool animated;
  int get total => columns * rows;
  int get targetLit => (progress.clamp(0, 1) * total).round();
  @override
  State<DotMatrixProgress> createState() => _DotMatrixProgressState();
}

class _DotMatrixProgressState extends State<DotMatrixProgress> {
  late int _lit = widget.animated ? 0 : widget.targetLit;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(covariant DotMatrixProgress old) {
    super.didUpdateWidget(old);
    if (!widget.animated) {
      _lit = widget.targetLit;
    } else {
      _arm();
    }
  }

  void _arm() {
    if (!widget.animated || _lit == widget.targetLit || (_tick?.isActive ?? false)) return;
    _tick = Timer.periodic(KataMotion.dotStep, (t) {
      if (!mounted) return t.cancel();
      setState(() => _lit += (widget.targetLit - _lit).sign);
      if (_lit == widget.targetLit) t.cancel();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final lit = (widget.animated && !KataMotion.reduced(context)) ? _lit : widget.targetLit;
    return SizedBox(
      width: widget.columns * widget.dot + (widget.columns - 1) * widget.gap,
      child: Wrap(spacing: widget.gap, runSpacing: widget.gap, children: [
        for (var i = 0; i < widget.total; i++)
          AnimatedContainer(
            duration: KataMotion.dotStep,
            width: widget.dot,
            height: widget.dot,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < lit ? p.fg : (i == lit ? p.muted : (i == lit + 1 ? p.hairline : p.surface)),
            ),
          ),
      ]),
    );
  }
}
