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
