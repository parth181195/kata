import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kata_ui/kata_ui.dart';

/// Full-screen photo viewer: swipe *or* arrows between photos, pinch/double-tap to zoom,
/// credit line, close. A mouse has no swipe, so on desktop the arrows and the keyboard are
/// the only way through — they are not decoration.
Future<void> showImageViewer(BuildContext context, {required List<String> urls, int initialIndex = 0, String? credit}) {
  if (urls.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: KataMotion.page,
      reverseTransitionDuration: KataMotion.pageOut,
      pageBuilder: (_, _, _) => _ImageViewer(urls: urls, initialIndex: initialIndex.clamp(0, urls.length - 1), credit: credit),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.urls, required this.initialIndex, this.credit});
  final List<String> urls;
  final int initialIndex;
  final String? credit;
  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final PageController _page = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed = false;
  final _controllers = <int, TransformationController>{};

  final _focus = FocusNode();

  TransformationController _ctl(int i) => _controllers.putIfAbsent(i, TransformationController.new);

  bool get _canBack => _index > 0;
  bool get _canForward => _index < widget.urls.length - 1;

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.urls.length - 1);
    if (next == _index) return;
    _ctl(_index).value = Matrix4.identity(); // leave a zoomed frame behind at 1:1
    _page.animateToPage(next, duration: KataMotion.page, curve: KataMotion.curve);
  }

  @override
  void dispose() {
    _focus.dispose();
    _page.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleZoom(int i, TapDownDetails d) {
    final c = _ctl(i);
    if (c.value != Matrix4.identity()) {
      c.value = Matrix4.identity();
      setState(() => _zoomed = false);
    } else {
      final p = d.localPosition;
      c.value = Matrix4.identity()
        ..translateByDouble(-p.dx * 1.5, -p.dy * 1.5, 0, 1)
        ..scaleByDouble(2.5, 2.5, 1, 1);
      setState(() => _zoomed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (_, e) {
          if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
          switch (e.logicalKey) {
            case LogicalKeyboardKey.arrowRight:
              _go(1);
            case LogicalKeyboardKey.arrowLeft:
              _go(-1);
            case LogicalKeyboardKey.escape:
              Navigator.of(context).pop();
            default:
              return KeyEventResult.ignored;
          }
          return KeyEventResult.handled;
        },
        child: Stack(fit: StackFit.expand, children: [
        PageView.builder(
          controller: _page,
          physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
          onPageChanged: (i) => setState(() => _index = i),
          itemCount: widget.urls.length,
          itemBuilder: (_, i) => GestureDetector(
            key: ValueKey('viewer-$i'),
            onDoubleTapDown: (d) => _toggleZoom(i, d),
            onDoubleTap: () {},
            child: InteractiveViewer(
              transformationController: _ctl(i),
              minScale: 1,
              maxScale: 5,
              onInteractionEnd: (_) => setState(() => _zoomed = _ctl(i).value != Matrix4.identity()),
              child: Center(
                child: Image(
                  image: CachedNetworkImageProvider(widget.urls[i]),
                  fit: BoxFit.contain,
                  frameBuilder: (_, child, frame, sync) => frame == null && !sync ? const Center(child: KataDotsLoader(color: Colors.white)) : child,
                  errorBuilder: (_, _, _) => Center(child: Text('COULDN’T LOAD', style: KataType.monoStyle(size: 10, color: KataColors.grey500))),
                ),
              ),
            ),
          ),
        ),
        // arrows: the only way through with a mouse
        if (widget.urls.length > 1) ...[
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Center(child: Opacity(opacity: _canBack ? 1 : 0.25, child: _Circle(onTap: _canBack ? () => _go(-1) : null, child: const Icon(Icons.arrow_back, size: 16, color: Colors.white)))),
          ),
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(child: Opacity(opacity: _canForward ? 1 : 0.25, child: _Circle(onTap: _canForward ? () => _go(1) : null, child: const Icon(Icons.arrow_forward, size: 16, color: Colors.white)))),
          ),
        ],
        // top bar
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(children: [
                _Circle(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.close, size: 16, color: Colors.white)),
                const Spacer(),
                if (widget.urls.length > 1)
                  Text('${_index + 1} / ${widget.urls.length}', style: KataType.monoStyle(size: 10.5, weight: FontWeight.w500, color: KataColors.grey300, letterSpacing: 0.14)),
              ]),
            ),
          ),
        ),
        // bottom: credit + dots
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (widget.urls.length > 1)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 0; i < widget.urls.length; i++) ...[
                      if (i > 0) const SizedBox(width: 7),
                      // square dots (Nothing style), the current one lit
                      AnimatedContainer(
                        duration: KataMotion.tap,
                        width: 5,
                        height: 5,
                        color: i == _index ? Colors.white : KataColors.grey700,
                      ),
                    ],
                  ]),
                if (widget.credit != null) ...[
                  const SizedBox(height: 12),
                  Text(widget.credit!.toUpperCase(), textAlign: TextAlign.center, style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: KataColors.grey500, letterSpacing: 0.14)),
                  const SizedBox(height: 4),
                  Text(widget.urls.length > 1 ? 'ARROWS TO MOVE · DOUBLE-TAP TO ZOOM' : 'PINCH OR DOUBLE-TAP TO ZOOM',
                      style: KataType.monoStyle(size: 8.5, color: KataColors.grey700, letterSpacing: 0.14)),
                ],
              ]),
            ),
          ),
        ),
        ]),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: 0.55),
    shape: const CircleBorder(side: BorderSide(color: Color(0x80FFFFFF))),
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: SizedBox(width: 36, height: 36, child: Center(child: child))),
  );
}
