import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/ink.dart';

void main() {
  test('contrast ratio matches the WCAG definition at the extremes', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.1));
    expect(contrastRatio(const Color(0xFF808080), const Color(0xFF808080)), closeTo(1, 0.01));
  });

  test('ink is legible on its ground even when the photo is pale', () {
    const ground = Color(0xFFF4EFE3);
    const pale = [Color(0xFFFDFBF7), Color(0xFFF6F1E8), Color(0xFFEFE9DD)];
    for (var seed = 0; seed < 200; seed++) {
      final ink = pickInk(family: kInkFamilies['postmark']!, palette: pale, ground: ground, seed: seed);
      expect(contrastRatio(ink, ground), greaterThanOrEqualTo(3.0), reason: 'seed $seed produced unreadable ink');
    }
  });

  test('ink is legible on a dark ground too', () {
    const ground = Color(0xFF14161A);
    const dark = [Color(0xFF1A1C20), Color(0xFF23262B)];
    for (var seed = 0; seed < 200; seed++) {
      final ink = pickInk(family: kInkFamilies['lab']!, palette: dark, ground: ground, seed: seed);
      expect(contrastRatio(ink, ground), greaterThanOrEqualTo(3.0), reason: 'seed $seed produced unreadable ink');
    }
  });

  test('ink stays in its family: a postmark never comes out green', () {
    const ground = Color(0xFFF4EFE3);
    const greens = [Color(0xFF1E5E2A), Color(0xFF2F7A3B), Color(0xFF7FBF4D)];
    for (var seed = 0; seed < 50; seed++) {
      final ink = pickInk(family: kInkFamilies['postmark']!, palette: greens, ground: ground, seed: seed);
      expect(ink.r, greaterThanOrEqualTo(ink.g), reason: 'seed $seed drifted out of the red-black family');
    }
  });

  test('the same seed gives the same ink', () {
    const ground = Color(0xFFF4EFE3);
    const palette = [Color(0xFF8A2B1C), Color(0xFF3C4A5A)];
    final a = pickInk(family: kInkFamilies['archive']!, palette: palette, ground: ground, seed: 42);
    final b = pickInk(family: kInkFamilies['archive']!, palette: palette, ground: ground, seed: 42);
    expect(a, b);
  });
}
