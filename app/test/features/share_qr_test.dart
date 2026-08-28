import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/features/share/card_templates.dart';
import 'package:kata/features/share/kata_code_qr.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

/// The worst payload a real user plausibly produces: a Japanese name, a Japanese
/// attribution and a source URL, all percent-encoded, on top of a recipe with
/// every optional field set. This is not a synthetic worst case — Kata is a Fuji
/// app, and this is what a recipe from a Japanese blog looks like.
const _worst = OfrRecipe(
    name: '夏の海辺の富士フイルムレシピ', sensors: ['X-Trans V', 'X-Trans IV'],
    sourceAttribution: '富士フイルム写真家協会', sourceUrl: 'https://example.jp/recipes/natsu-no-umibe',
    filmSimulation: 'Classic Negative', dynamicRange: 'DR400', dRangePriority: 'Strong',
    grainRoughness: 'Strong', grainSize: 'Large', colorChromeEffect: 'Strong', colorChromeFxBlue: 'Strong',
    whiteBalance: 'Kelvin', wbKelvin: 7500, whiteBalanceRed: 9, whiteBalanceBlue: -9,
    highlight: 4, shadow: 4, color: 4, sharpness: 4, highIsoNr: 4, clarity: 5,
    monochromaticColorWarmCool: 9, monochromaticColorMagentaGreen: -9);

const _long = OfrRecipe(
    name: 'Kodak T-Max 100 Hard Tone', sensors: ['X-Trans V'], filmSimulation: 'Acros Red', dynamicRange: 'DR400',
    dRangePriority: 'Off', grainRoughness: 'Strong', grainSize: 'Large', whiteBalance: 'Kelvin', wbKelvin: 5800,
    whiteBalanceRed: 3, whiteBalanceBlue: -4, highlight: 1.5, shadow: 2, sharpness: 2, highIsoNr: -4, clarity: -3,
    monochromaticColorWarmCool: 4, monochromaticColorMagentaGreen: -2, sourceAttribution: 'parth');

void main() {
  test('an exported card renders the QR big enough to survive a messenger', () {
    // What matters is pixels per module in the PNG someone actually receives: below ~5 a
    // recompressed screenshot stops scanning reliably.
    const smallestQrOnACard = 104.0; // the tightest template
    final payload = KataCode.encode(_long, credit: 'parth');
    // qr_flutter picks the smallest version that fits; worst case for us is a long payload
    final modules = _modulesFor(payload.length);
    final quietZone = smallestQrOnACard * 0.08 * 2;
    final pxPerModule = (smallestQrOnACard - quietZone) * kCardPixelRatio / modules;

    expect(pxPerModule, greaterThanOrEqualTo(5.0),
        reason: 'payload of ${payload.length} bytes → $modules modules at ${pxPerModule.toStringAsFixed(1)}px each');
    expect(kCardWidth * kCardPixelRatio, closeTo(1560, 1), reason: 'about what messengers downscale to');
  });

  // The constant above only checks the number we think the slot is. This checks
  // the code that actually gets painted, on every template, for a payload a real
  // user can produce — which is how the 104px slot shipped a Japanese recipe with
  // an unscannable code.
  testWidgets('every template paints a code that survives a messenger', (t) async {
    final payload = KataCode.encode(_worst, credit: _worst.sourceAttribution);
    final modules = _modulesFor(payload.length);

    // the recipe page of every template carries the code; the photo page never does
    t.view.physicalSize = const Size(kCardWidth, 1600);
    t.view.devicePixelRatio = 1;
    for (final template in ShareTemplate.values) {
      await t.pumpWidget(MaterialApp(
        theme: KataTheme.light(),
        home: Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: kCardWidth,
              child: ShareCard(ShareSpec(
                recipe: Recipe(id: 'w1', ofr: _worst),
                template: template,
                credit: _worst.sourceAttribution!,
              )),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();

      // the painted rect, not the requested size — the code scales into the room page 1 leaves
      final rect = t.getRect(find.byType(KataCodeQr));
      final quiet = rect.width * 0.08 * 2;
      final pxPerModule = (rect.width - quiet) * kCardPixelRatio / modules;
      expect(pxPerModule, greaterThanOrEqualTo(kMinQrPxPerModule),
          reason: '${template.code}: ${payload.length}B → $modules modules in '
              '${rect.width.toStringAsFixed(0)}px = ${pxPerModule.toStringAsFixed(2)}px per module');
    }
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  });
}

/// Module count for the smallest QR version that holds [bytes] at error-correction
/// level M. Version n is (4n + 17) modules square; byte capacities from the QR spec.
///
/// The table used to stop at version 12 and return version 12 for anything larger,
/// which meant a payload too big to fit was reported as *less* dense than it is —
/// the one case the assertion exists to catch. It now throws instead.
int _modulesFor(int bytes) {
  const capacityM = {
    1: 14, 2: 26, 3: 42, 4: 62, 5: 84, 6: 106, 7: 122, 8: 152, 9: 180, 10: 213,
    11: 251, 12: 287, 13: 331, 14: 362, 15: 412, 16: 450, 17: 504, 18: 560, 19: 624, 20: 666,
  };
  for (final e in capacityM.entries) {
    if (bytes <= e.value) return 4 * e.key + 17;
  }
  throw StateError('$bytes bytes needs a QR past version 20 — extend the table');
}
