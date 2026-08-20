import 'package:flutter_test/flutter_test.dart';
import 'package:kata/features/share/card_templates.dart';
import 'package:ofr/ofr.dart';

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
}

/// Module count for the smallest QR version that holds [bytes] at error-correction level M.
/// Version n is (4n + 17) modules square; byte capacities from the QR spec.
int _modulesFor(int bytes) {
  const capacityM = {1: 14, 2: 26, 3: 42, 4: 62, 5: 84, 6: 106, 7: 122, 8: 152, 9: 180, 10: 213, 11: 251, 12: 287};
  for (final e in capacityM.entries) {
    if (bytes <= e.value) return 4 * e.key + 17;
  }
  return 4 * 12 + 17;
}
