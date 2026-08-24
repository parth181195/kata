import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'grain_template.dart';

/// Film grain in Fujifilm's own grammar: strength × clump size, the two axes
/// a recipe's `GR-WS` carries. A curation input baked into each frame —
/// users never see grain controls.
enum GrainStrength {
  off('Off', 0),
  weak('Weak', 0.5),
  strong('Strong', 1.0);

  const GrainStrength(this.label, this.amount);
  final String label;
  final double amount;
}

enum GrainSize {
  small('Small', 1.7),
  large('Large', 3.1);

  const GrainSize(this.label, this.px);
  final String label;
  /// Clump size in physical pixels — resolution-true, so a 3× export renders
  /// finer, denser grain instead of blown-up preview noise.
  final double px;
}

class GrainSpec {
  const GrainSpec({this.strength = GrainStrength.off, this.size = GrainSize.small, this.seed = 7});
  final GrainStrength strength;
  final GrainSize size;
  final int seed;

  bool get isOff => strength == GrainStrength.off;

  String get _cacheKey => '$seed:${size.px}';
}

/// Lays authored grain over [child]: a Dart-generated correlated tile
/// (band-passed, seamless — see GrainTemplate) sampled by a fragment shader
/// with per-block random offsets, composited with an overlay blend so the
/// surface beneath supplies the tonal response. CustomPainter + FragmentShader
/// throughout: identical on Impeller and Skia, macOS/Android/Linux alike.
class GrainOverlay extends StatefulWidget {
  const GrainOverlay({super.key, required this.spec, required this.child});
  final GrainSpec spec;
  final Widget child;

  /// Export renders the boundary at a higher pixel ratio than the screen;
  /// grain must be generated in those pixels or it exports as magnified
  /// blocks. rasterizePng sets this around toImage; painters repaint on it.
  static final ValueNotifier<double> rasterScale = ValueNotifier<double>(1);

  @override
  State<GrainOverlay> createState() => _GrainOverlayState();
}

class _GrainOverlayState extends State<GrainOverlay> {
  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram>? _programLoading;
  static final Map<String, ui.Image> _templates = {};
  static final Map<String, Future<ui.Image>> _templateLoading = {};

  static Future<ui.FragmentProgram> _loadProgram() =>
      _programLoading ??= ui.FragmentProgram.fromAsset('shaders/grain_overlay.frag').then((p) => _program = p);

  static Future<ui.Image> _loadTemplate(GrainSpec spec) => _templateLoading.putIfAbsent(
      spec._cacheKey, () => GrainTemplate.image(seed: spec.seed, grainPx: spec.size.px).then((i) => _templates[spec._cacheKey] = i));

  @override
  void initState() {
    super.initState();
    _kick();
  }

  @override
  void didUpdateWidget(GrainOverlay old) {
    super.didUpdateWidget(old);
    if (old.spec._cacheKey != widget.spec._cacheKey) _kick();
  }

  void _kick() {
    if (widget.spec.isOff) return;
    if (_program == null || _templates[widget.spec._cacheKey] == null) {
      Future.wait([_loadProgram(), _loadTemplate(widget.spec)]).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final program = _program;
    final template = _templates[spec._cacheKey];
    if (spec.isOff || program == null || template == null) return widget.child;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio;
    return CustomPaint(
      foregroundPainter: _GrainPainter(program, template, spec, dpr),
      child: widget.child,
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.program, this.template, this.spec, this.dpr) : super(repaint: GrainOverlay.rasterScale);
  final ui.FragmentProgram program;
  final ui.Image template;
  final GrainSpec spec;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader()
      ..setFloat(0, dpr * GrainOverlay.rasterScale.value)
      ..setFloat(1, spec.strength.amount)
      ..setFloat(2, spec.seed.toDouble())
      ..setImageSampler(0, template);
    canvas.drawRect(Offset.zero & size, Paint()
      ..shader = shader
      ..blendMode = BlendMode.overlay);
  }

  @override
  bool shouldRepaint(_GrainPainter o) =>
      o.spec.strength != spec.strength || o.spec._cacheKey != spec._cacheKey || o.dpr != dpr || o.template != template;
}
