import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata_ui/kata_ui.dart';

void main() {
  testWidgets('dark and light palettes resolve through context.kata', (t) async {
    late KataPalette dark, light;
    await t.pumpWidget(MaterialApp(theme: KataTheme.dark(), home: Builder(builder: (c) { dark = c.kata; return const SizedBox(); })));
    await t.pumpWidget(MaterialApp(theme: KataTheme.light(), home: Builder(builder: (c) { light = c.kata; return const SizedBox(); })));
    await t.pumpAndSettle();
    expect(dark.bg, KataColors.black);
    expect(dark.fg, KataColors.white);
    expect(dark.hairline, KataColors.grey700);
    expect(light.bg, KataColors.white);
    expect(light.hairline, KataColors.grey300);
    expect(dark.red, KataColors.red);
  });
  test('type styles use bundled families via package', () {
    final d = KataType.displayStyle();
    expect(d.fontFamily, 'packages/kata_ui/Doto');
    expect(d.fontWeight, FontWeight.w800);
    expect(KataType.monoStyle().fontFamily, 'packages/kata_ui/JetBrains Mono');
    expect(KataType.labelStyle().letterSpacing, closeTo(8.5 * 0.16, 0.01));
  });
}
