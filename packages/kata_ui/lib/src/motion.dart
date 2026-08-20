import 'package:flutter/material.dart';

/// Motion tokens. Everything short and deliberate; honours "reduce motion".
class KataMotion {
  static const tap = Duration(milliseconds: 90);
  static const sheetIn = Duration(milliseconds: 260);
  static const sheetOut = Duration(milliseconds: 180);
  static const page = Duration(milliseconds: 260);
  static const pageOut = Duration(milliseconds: 180);
  static const dotStep = Duration(milliseconds: 60);
  static const curve = Cubic(0.2, 0, 0, 1);

  static bool reduced(BuildContext c) => MediaQuery.maybeDisableAnimationsOf(c) ?? false;
}

/// Scales its child to [pressedScale] while a pointer is down. Pure feedback — taps are still
/// handled by the child's InkWell; this only listens.
class KataTapScale extends StatefulWidget {
  const KataTapScale({super.key, required this.child, this.enabled = true, this.pressedScale = 0.98});
  final Widget child;
  final bool enabled;
  final double pressedScale;
  @override
  State<KataTapScale> createState() => _KataTapScaleState();
}

class _KataTapScaleState extends State<KataTapScale> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || KataMotion.reduced(context)) return widget.child;
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: KataMotion.tap,
        curve: Curves.linear,
        child: widget.child,
      ),
    );
  }
}

/// One-shot entrance: fade + 8px rise over [KataMotion.page], optionally delayed (for staggers).
class KataFadeIn extends StatefulWidget {
  const KataFadeIn({super.key, required this.child, this.delay = Duration.zero, this.offsetY = 8, this.duration = KataMotion.page});
  final Widget child;
  final Duration delay;
  final double offsetY;
  final Duration duration;
  @override
  State<KataFadeIn> createState() => _KataFadeInState();
}

class _KataFadeInState extends State<KataFadeIn> {
  bool _go = false;
  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _go = true;
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) setState(() => _go = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (KataMotion.reduced(context)) return widget.child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _go ? 1 : 0),
      duration: widget.duration,
      curve: KataMotion.curve,
      child: widget.child,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, widget.offsetY * (1 - t)), child: child),
      ),
    );
  }
}

/// Route transition: fade + slight rise in, quick fade out.
/// kata_ui has no router dependency — feed [transitionsBuilder] + durations to your router's
/// custom page (go_router `CustomTransitionPage`, or a `PageRouteBuilder`).
class KataPageTransition {
  static Widget transitionsBuilder(BuildContext context, Animation<double> animation, Animation<double> secondary, Widget child) {
    if (KataMotion.reduced(context)) return child;
    final t = CurvedAnimation(parent: animation, curve: KataMotion.curve, reverseCurve: Curves.easeOut);
    return FadeTransition(
      opacity: t,
      child: SlideTransition(position: Tween(begin: const Offset(0, 0.012), end: Offset.zero).animate(t), child: child),
    );
  }

  static PageRouteBuilder<T> route<T>({required WidgetBuilder builder, RouteSettings? settings}) => PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: KataMotion.page,
    reverseTransitionDuration: KataMotion.pageOut,
    pageBuilder: (c, _, _) => builder(c),
    transitionsBuilder: transitionsBuilder,
  );
}

/// Indeterminate loader: three dots pulsing in sequence. Static (middle dot lit) under reduce-motion.
class KataDotsLoader extends StatefulWidget {
  const KataDotsLoader({super.key, this.color, this.dot = 5, this.gap = 5, this.period = const Duration(milliseconds: 900)});
  final Color? color;
  final double dot, gap;
  final Duration period;
  @override
  State<KataDotsLoader> createState() => _KataDotsLoaderState();
}

class _KataDotsLoaderState extends State<KataDotsLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // no ticker under reduce-motion (also lets widget tests settle)
    if (KataMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? DefaultTextStyle.of(context).style.color ?? Colors.white;
    final reduced = KataMotion.reduced(context);
    Widget dot(double opacity) => Opacity(
      opacity: opacity,
      // square, like the slot marks and the page dots — round pips read as another product
      child: Container(width: widget.dot, height: widget.dot, color: color),
    );
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) SizedBox(width: widget.gap),
            dot(reduced ? (i == 1 ? 1 : 0.35) : _pulse((_c.value - i / 3) % 1)),
          ],
        ]),
      ),
    );
  }

  // 0.3 → 1 → 0.3 over one cycle, peak sharp-ish
  static double _pulse(double t) {
    final x = (t < 0.5 ? t * 2 : (1 - t) * 2);
    return 0.3 + 0.7 * Curves.easeOut.transform(x);
  }
}

/// Slow opacity breathe for placeholders (skeletons). Static under reduce-motion.
class KataPulse extends StatefulWidget {
  const KataPulse({super.key, required this.child, this.min = 0.55, this.period = const Duration(milliseconds: 1400)});
  final Widget child;
  final double min;
  final Duration period;
  @override
  State<KataPulse> createState() => _KataPulseState();
}

class _KataPulseState extends State<KataPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KataMotion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (KataMotion.reduced(context)) return widget.child;
    return FadeTransition(opacity: Tween(begin: 1.0, end: widget.min).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)), child: widget.child);
  }
}
