import 'package:flutter/material.dart';

class KataColors {
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);
  static const grey950 = Color(0xFF0A0A0A);
  static const grey900 = Color(0xFF1A1A1A);
  static const grey700 = Color(0xFF2E2E2E);
  /// Dark-mode hairline: the design's #2E2E2E reads near-black on OLED, so outlines use this.
  static const hairlineDark = Color(0xFF3A3A3A);
  static const grey500 = Color(0xFF8A8A8A);
  static const grey300 = Color(0xFFD9D9D9);
  static const paper = Color(0xFFF5F5F5);
  static const red = Color(0xFFD71921);
}

/// Stroke widths. The design says 1dp; on OLED a touch thicker reads better.
class KataStroke {
  static const hairline = 1.5;
  static const emphasis = 2.0;
}

class KataRadii {
  static const card = 18.0;
  static const cardSm = 14.0;
  static const sheet = 26.0;
  static const slot = 9.0;
  static const pill = 999.0;
}

/// Font families are bundled in this package; Flutter addresses them as `packages/kata_ui/<family>`.
class KataType {
  static const pkg = 'kata_ui';
  static const display = 'packages/$pkg/Doto';
  static const body = 'packages/$pkg/Inter';
  static const mono = 'packages/$pkg/JetBrains Mono';

  static TextStyle displayStyle({
    double size = 24,
    FontWeight weight = FontWeight.w800,
    Color? color,
    double letterSpacing = 0.03,
    double height = 1.05,
  }) =>
      TextStyle(fontFamily: display, fontSize: size, fontWeight: weight, color: color, letterSpacing: size * letterSpacing, height: height);

  static TextStyle bodyStyle({double size = 13, FontWeight weight = FontWeight.w400, Color? color, double height = 1.4}) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: weight, color: color, height: height);

  static TextStyle monoStyle({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double letterSpacing = 0,
    double height = 1.2,
  }) =>
      TextStyle(fontFamily: mono, fontSize: size, fontWeight: weight, color: color, letterSpacing: size * letterSpacing, height: height);

  /// Tiny uppercase label over values: Inter 8.5 w500, .16em.
  static TextStyle labelStyle({Color? color, double size = 8.5}) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: FontWeight.w500, color: color, letterSpacing: size * 0.16, height: 1);
}
