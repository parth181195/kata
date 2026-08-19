import 'package:flutter/material.dart';

import 'tokens.dart';

class KataPalette extends ThemeExtension<KataPalette> {
  const KataPalette({
    required this.dark,
    required this.bg,
    required this.fg,
    required this.hairline,
    required this.hairlineStrong,
    required this.muted,
    required this.dim,
    required this.surface,
    required this.code,
    this.red = KataColors.red,
  });
  final bool dark;
  final Color bg, fg, hairline, hairlineStrong, muted, dim, surface, code, red;

  static const darkPalette = KataPalette(
      dark: true,
      bg: KataColors.black,
      fg: KataColors.white,
      hairline: KataColors.grey700,
      hairlineStrong: KataColors.grey500,
      muted: KataColors.grey500,
      dim: KataColors.grey300,
      surface: KataColors.grey900,
      code: KataColors.grey950);
  static const lightPalette = KataPalette(
      dark: false,
      bg: KataColors.white,
      fg: KataColors.black,
      hairline: KataColors.grey300,
      hairlineStrong: KataColors.grey500,
      muted: KataColors.grey500,
      dim: KataColors.grey700,
      surface: KataColors.paper,
      code: KataColors.paper);

  @override
  KataPalette copyWith({Color? bg, Color? fg}) => KataPalette(
      dark: dark, bg: bg ?? this.bg, fg: fg ?? this.fg, hairline: hairline, hairlineStrong: hairlineStrong, muted: muted, dim: dim, surface: surface, code: code, red: red);

  @override
  KataPalette lerp(ThemeExtension<KataPalette>? other, double t) => t < 0.5 ? this : (other as KataPalette? ?? this);
}

extension KataContext on BuildContext {
  KataPalette get kata => Theme.of(this).extension<KataPalette>() ?? KataPalette.darkPalette;
}

class KataTheme {
  static ThemeData dark() => _build(KataPalette.darkPalette);
  static ThemeData light() => _build(KataPalette.lightPalette);

  static ThemeData _build(KataPalette p) {
    final base = ThemeData(brightness: p.dark ? Brightness.dark : Brightness.light, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      colorScheme: base.colorScheme.copyWith(primary: p.fg, onPrimary: p.bg, surface: p.bg, onSurface: p.fg, outline: p.hairline, error: p.red),
      splashColor: p.fg.withValues(alpha: 0.06),
      highlightColor: p.fg.withValues(alpha: 0.04),
      dividerColor: p.hairline,
      textTheme: base.textTheme.apply(fontFamily: KataType.body, bodyColor: p.fg, displayColor: p.fg),
      appBarTheme: AppBarTheme(backgroundColor: p.bg, foregroundColor: p.fg, elevation: 0, scrolledUnderElevation: 0),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: p.bg, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(KataRadii.sheet)))),
      extensions: [p],
    );
  }
}
