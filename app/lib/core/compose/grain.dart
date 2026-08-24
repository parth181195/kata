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
  /// Clump size on the sheet, in the screen pixels the preview is drawn with.
  /// It stays that size relative to the sheet at every export scale.
  final double px;
}

class GrainSpec {
  const GrainSpec({this.strength = GrainStrength.off, this.size = GrainSize.small, this.seed = 7, this.matchPx});
  final GrainStrength strength;
  final GrainSize size;
  final int seed;
  /// Matched to the photo (derived from its ISO): the stock's tooth sits in
  /// the same grain regime as the picture. Overrides [size] when set.
  final double? matchPx;

  double get px => matchPx ?? size.px;

  bool get isOff => strength == GrainStrength.off;

  String _cacheKey(int tile) => '$seed:${px.toStringAsFixed(2)}:$tile';
}

/// How one grain spec is drawn at a given screen density and raster scale.
///
/// Grain belongs to the paper, so its size on the sheet must not depend on how
/// many pixels we happen to be rendering the sheet into: a 4× export resolves
/// the same tooth more finely, it doesn't shrink it (Newson et al. render the
/// grain model in the medium's coordinates and let the output grid scale —
/// docs/design/waku-grain.md §1, §3a). [tile] only buys resolution: the tooth's
/// size and the tile's repeat on the sheet both come out independent of it,
/// which is what the geometry test pins.
class GrainGeometry {
  const GrainGeometry({required this.tile, required this.uScale, required this.uTile, required this.templatePx});

  /// Template magnification: 1 = the 128² preview tile.
  final int tile;

  /// Logical canvas pixels → template texels.
  final double uScale;

  /// Template size in texels.
  final double uTile;

  /// Clump size in texels, for generating that template.
  final double templatePx;

  int get templateSize => (GrainTemplate.size * tile);

  /// Clump size on the sheet, in logical canvas pixels — invariant.
  double get clumpOnSheet => templatePx / uScale;

  /// Distance before the tile repeats on the sheet, in logical canvas pixels — invariant.
  double get repeatOnSheet => uTile / uScale;

  static const maxTile = 4; // beyond this the tile is magnified rather than regenerated

  /// Which template an export scale wants. Doesn't depend on the screen, so it
  /// can be asked for before there's a MediaQuery to ask.
  static int tileFor(double raster) => raster.ceil().clamp(1, maxTile);

  static GrainGeometry of(GrainSpec spec, {required double dpr, required double raster}) {
    final tile = tileFor(raster);
    return GrainGeometry(
      tile: tile,
      uScale: dpr * tile,
      uTile: (GrainTemplate.size * tile).toDouble(),
      templatePx: spec.px * tile,
    );
  }
}

/// Lays authored grain over [child]: a Dart-generated correlated tile
/// (band-passed, seamless — see GrainTemplate) sampled by a fragment shader,
/// composited with an overlay blend so the surface beneath supplies the tonal
/// response. CustomPainter + FragmentShader throughout: identical on Impeller
/// and Skia, macOS/Android/Linux alike.
class GrainOverlay extends StatefulWidget {
  const GrainOverlay({super.key, required this.spec, required this.child});
  final GrainSpec spec;
  final Widget child;

  /// Export renders the boundary at a higher pixel ratio than the screen. The
  /// tooth keeps its size on the sheet either way; this drives how finely the
  /// tile is generated so the export resolves it instead of magnifying it.
  static final ValueNotifier<double> rasterScale = ValueNotifier<double>(1);

  /// Completes once every template asked for so far has been generated —
  /// rasterizePng awaits this after raising [rasterScale], so the export can't
  /// rasterise the preview tile.
  static Future<void> ready() => _GrainOverlayState.ready();

  @override
  State<GrainOverlay> createState() => _GrainOverlayState();
}

class _GrainOverlayState extends State<GrainOverlay> {
  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram>? _programLoading;
  static final Map<String, ui.Image> _templates = {};
  static final Map<String, Future<ui.Image>> _templateLoading = {};

  static Future<void> ready() async {
    while (true) {
      final pending = [..._templateLoading.values, ?_programLoading];
      await Future.wait(pending);
      // a load that finished may have kicked another (a new tile scale)
      if (pending.length == _templateLoading.length + (_programLoading == null ? 0 : 1)) return;
    }
  }

  static Future<ui.FragmentProgram> _loadProgram() =>
      _programLoading ??= ui.FragmentProgram.fromAsset('shaders/grain_overlay.frag').then((p) => _program = p);

  static Future<ui.Image> _loadTemplate(GrainSpec spec, int tile) => _templateLoading.putIfAbsent(
      spec._cacheKey(tile),
      () => GrainTemplate.image(seed: spec.seed, grainPx: spec.px * tile, size: GrainTemplate.size * tile)
          .then((i) => _templates[spec._cacheKey(tile)] = i));

  double _raster = GrainOverlay.rasterScale.value;

  @override
  void initState() {
    super.initState();
    GrainOverlay.rasterScale.addListener(_onRaster);
    _kick();
  }

  @override
  void didUpdateWidget(GrainOverlay old) {
    super.didUpdateWidget(old);
    if (old.spec._cacheKey(1) != widget.spec._cacheKey(1)) _kick();
  }

  @override
  void dispose() {
    GrainOverlay.rasterScale.removeListener(_onRaster);
    super.dispose();
  }

  void _onRaster() {
    if (GrainOverlay.rasterScale.value == _raster) return;
    _raster = GrainOverlay.rasterScale.value;
    _kick();
    if (mounted) setState(() {});
  }

  /// The screen's density, or 1 in a test harness with no view.
  double get _dpr {
    final mq = MediaQuery.maybeDevicePixelRatioOf(context);
    if (mq != null) return mq;
    final v = View.maybeOf(context);
    return v?.devicePixelRatio ?? 1;
  }

  /// Kicks the loads for the current export scale. Deliberately free of
  /// MediaQuery: this runs from initState, where there is no inherited widget
  /// to depend on yet — and the tile doesn't depend on the screen anyway.
  void _kick() {
    if (widget.spec.isOff) return;
    final tile = GrainGeometry.tileFor(_raster);
    if (_program != null && _templates[widget.spec._cacheKey(tile)] != null) return;
    Future.wait([_loadProgram(), _loadTemplate(widget.spec, tile)]).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final program = _program;
    if (spec.isOff || program == null) return widget.child;
    var g = GrainGeometry.of(spec, dpr: _dpr, raster: _raster);
    var template = _templates[spec._cacheKey(g.tile)];
    if (template == null) {
      // the export tile is still generating: the preview tile draws the same
      // tooth, just softer, rather than the sheet flashing bare
      g = GrainGeometry.of(spec, dpr: _dpr, raster: 1);
      template = _templates[spec._cacheKey(g.tile)];
    }
    if (template == null) return widget.child;
    return CustomPaint(
      foregroundPainter: _GrainPainter(program, template, spec, g),
      child: widget.child,
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.program, this.template, this.spec, this.geometry);
  final ui.FragmentProgram program;
  final ui.Image template;
  final GrainSpec spec;
  final GrainGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader()
      ..setFloat(0, geometry.uScale)
      ..setFloat(1, spec.strength.amount)
      ..setFloat(2, spec.seed.toDouble())
      ..setFloat(3, geometry.uTile)
      ..setImageSampler(0, template);
    canvas.drawRect(Offset.zero & size, Paint()
      ..shader = shader
      ..blendMode = BlendMode.overlay);
  }

  @override
  bool shouldRepaint(_GrainPainter o) =>
      o.spec.strength != spec.strength ||
      o.geometry.uScale != geometry.uScale ||
      o.geometry.uTile != geometry.uTile ||
      o.template != template;
}
