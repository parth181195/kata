import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';

/// Full-screen photo viewer: swipe between photos, pinch/double-tap to zoom, credit line, close.
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

  TransformationController _ctl(int i) => _controllers.putIfAbsent(i, TransformationController.new);

  @override
  void dispose() {
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
      body: Stack(fit: StackFit.expand, children: [
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
                      if (i > 0) const SizedBox(width: 6),
                      AnimatedContainer(
                        duration: KataMotion.tap,
                        width: i == _index ? 14 : 5,
                        height: 5,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: i == _index ? Colors.white : KataColors.grey700),
                      ),
                    ],
                  ]),
                if (widget.credit != null) ...[
                  const SizedBox(height: 12),
                  Text(widget.credit!.toUpperCase(), textAlign: TextAlign.center, style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: KataColors.grey500, letterSpacing: 0.14)),
                  const SizedBox(height: 4),
                  Text('PINCH OR DOUBLE-TAP TO ZOOM', style: KataType.monoStyle(size: 8.5, color: KataColors.grey700, letterSpacing: 0.14)),
                ],
              ]),
            ),
          ),
        ),
      ]),
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
