import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Film grain in Fujifilm's own grammar: an effect strength crossed with a
/// clump size — the same two axes a recipe's `GR-WS` carries.
enum GrainStrength {
  off('Off', 0),
  weak('Weak', 0.22),
  strong('Strong', 0.42);

  const GrainStrength(this.label, this.amount);
  final String label;
  /// Mix toward the grain reconstruction (see shaders/grain.frag).
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

  GrainSpec copyWith({GrainStrength? strength, GrainSize? size}) => GrainSpec(strength: strength ?? this.strength, size: size ?? this.size, seed: seed);
}

/// Develops [child] as film grain rather than overlaying noise: the shader
/// re-expresses the image as luminance-thresholded grain dots (density follows
/// brightness, like silver halide) and mixes them back in. Falls back to the
/// untouched child where shader filtering isn't available.
class FilmGrain extends StatelessWidget {
  const FilmGrain({super.key, required this.spec, required this.child});
  final GrainSpec spec;
  final Widget child;

  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram>? _loading;

  static Future<ui.FragmentProgram> _load() => _loading ??= ui.FragmentProgram.fromAsset('shaders/grain.frag').then((p) => _program = p);

  @override
  Widget build(BuildContext context) {
    if (spec.isOff || !ui.ImageFilter.isShaderFilterSupported) return child;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio;
    final program = _program;
    if (program == null) {
      // kick the load; grain appears on the frame after it lands
      _load();
      return FutureBuilder<ui.FragmentProgram>(
        future: _loading,
        builder: (_, snap) => snap.hasData ? _grained(snap.data!, dpr) : child,
      );
    }
    return _grained(program, dpr);
  }

  Widget _grained(ui.FragmentProgram program, double dpr) {
    // float indices 0–1 are the engine-set input size (the leading vec2)
    final shader = program.fragmentShader()
      ..setFloat(2, spec.size.px * dpr)
      ..setFloat(3, spec.strength.amount)
      ..setFloat(4, spec.seed.toDouble());
    return ImageFiltered(imageFilter: ui.ImageFilter.shader(shader), child: child);
  }
}
