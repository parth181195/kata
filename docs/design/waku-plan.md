# Waku Frames Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Waku's three layout-frames with authored *objects* — a stamp, a negative strip, an archive label — whose surface (type voice, ink, imperfection) is rolled from a single seed within each object's declared allowances.

**Architecture:** A frame declares three things: **identity** (hand-authored painters and geometry — perforations, sprockets, tombstone card), **slots** (where the shot's content lands), and **allowances** (which voices, inks and treatments the roll may draw). A `Roll` is a seeded draw from those allowances, biased by the photograph's own properties. The existing compose engine (`ComposeLayer`, `ComposeCanvasView`), ratio solver (`sheet_layout.dart`), grain measurement and export path are the substrate and do not change.

**Tech Stack:** Flutter 3.41 / Dart 3.11, `google_fonts` (bundled assets, runtime fetching disabled), existing `image` and `exif` packages. Tests: `flutter_test`.

**Spec:** `docs/design/waku-spec.md` — read it before starting. Supporting context: `docs/design/waku-inventory.md` (the 97 references and what each object needs), `docs/design/waku-grain.md` §7 (why the sheet's tooth comes from the photo).

## Global Constraints

- **One integer seeds everything.** Any output must be reproducible from `(photo, frameId, seed)`. No `Random()` without an explicit seed, anywhere in frame or roll code.
- **Bias is weighting, never forcing.** Every voice a frame allows keeps a non-zero probability regardless of the photo.
- **Ink must pass a contrast floor** against the ground it prints on: `contrastRatio(ink, ground) >= 3.0` (WCAG-style relative luminance ratio).
- **Fonts are bundled.** `GoogleFonts.config.allowRuntimeFetching = false` is set once at app start; every voice's font files ship in `app/assets/google_fonts/`.
- **Frames are Dart classes in v1.** No JSON documents, no fetching.
- **The sheet's grain comes from the photograph** via the existing `PhotoGrain` measurement — never invent a paper texture.
- **Grain renders on the exported frame only.** The live canvas passes `grain: false`; this is already how `ComposeCanvasView` works.
- **Every commit leaves `fvm flutter analyze` clean and `fvm flutter test` green.** Run both before each commit step.

---

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `app/lib/core/compose/voice.dart` | `Voice` (a display/text/data type pairing), the registry, and the photo→voice bias |
| `app/lib/core/compose/ink.dart` | `InkFamily`, choosing an ink from the photo's palette, the contrast floor |
| `app/lib/core/compose/treatment.dart` | `Treatment` (slip, bleed, pressure, speckle, wear) plus its painters |
| `app/lib/core/compose/roll.dart` | `Roll` — the seeded draw; `RollAxis`; `Pins` |
| `app/lib/features/waku/frames/frame.dart` | The `WakuObject` contract (identity + slots + allowances) and the registry |
| `app/lib/features/waku/frames/stamp.dart` | Object 1: postage stamp |
| `app/lib/features/waku/frames/negative_strip.dart` | Object 2: 35mm negative strip |
| `app/lib/features/waku/frames/label_card.dart` | Object 3: archive label card |
| `app/lib/features/waku/frames/barcode.dart` | Code 39 painter (used by label card and negative strip) |
| `app/lib/features/waku/dev_roll_grid.dart` | Dev-only screen: a grid of rolls for eyeball review |
| `app/test/core/voice_test.dart` | Registry and bias statistics |
| `app/test/core/ink_test.dart` | Contrast floor under adversarial palettes |
| `app/test/core/roll_test.dart` | Determinism, allowances, pins |
| `app/test/features/frames_test.dart` | Fuzz seeds × ratios across every registered object |

**Modified:**

| Path | Change |
|---|---|
| `app/lib/features/waku/waku_screen.dart` | Rewritten: one result, shuffle, per-axis pins, frames drawer, edit mode |
| `app/test/features/waku_test.dart` | Rewritten for the new screen |
| `app/pubspec.yaml` | `assets/google_fonts/` asset directory |
| `app/lib/main.dart` | Disable Google Fonts runtime fetching at start |

**Deleted:**

| Path | Why |
|---|---|
| `app/lib/features/waku/waku_frames.dart` | Polaroid, poster and words — layouts, superseded by objects (spec §8) |
| `app/lib/scratch_stamp.dart` | Throwaway spike; its painters are ported into `frames/stamp.dart` by Task 6 |

---

### Task 1: Voice — the type pairings and their bias

**Files:**
- Create: `app/lib/core/compose/voice.dart`
- Create: `app/test/core/voice_test.dart`
- Modify: `app/pubspec.yaml`
- Modify: `app/lib/main.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum VoiceId { postOffice, bureau, deco, civic }`; `class Voice { VoiceId id; String display, text, data; TextStyle displayStyle(double size, Color c); TextStyle textStyle(double size, Color c, {FontWeight weight, double tracking}); TextStyle dataStyle(double size, Color c); }`; `const Map<VoiceId, Voice> kVoices`; `Map<VoiceId, double> voiceWeights({required String? filmSim, required int? iso, required Set<VoiceId> allowed})`.

- [ ] **Step 1: Download the twelve font files**

Voices are four pairings of three roles. Download one file per family from Google Fonts into `app/assets/google_fonts/` using the exact filenames the `google_fonts` package expects (`Family-Weight.ttf`, no spaces):

```bash
cd /home/parth/WebstormProjects/fuji/app
mkdir -p assets/google_fonts
# Each URL is the direct TTF from the Google Fonts GitHub mirror.
base=https://raw.githubusercontent.com/google/fonts/main
curl -fsSL -o assets/google_fonts/Oswald-Bold.ttf            $base/ofl/oswald/Oswald%5Bwght%5D.ttf
curl -fsSL -o assets/google_fonts/BarlowCondensed-Medium.ttf $base/ofl/barlowcondensed/BarlowCondensed-Medium.ttf
curl -fsSL -o assets/google_fonts/SpaceMono-Regular.ttf      $base/ofl/spacemono/SpaceMono-Regular.ttf
curl -fsSL -o assets/google_fonts/ArchivoBlack-Regular.ttf   $base/ofl/archivoblack/ArchivoBlack-Regular.ttf
curl -fsSL -o assets/google_fonts/IBMPlexSans-Medium.ttf     $base/ofl/ibmplexsans/IBMPlexSans-Medium.ttf
curl -fsSL -o assets/google_fonts/IBMPlexMono-Medium.ttf     $base/ofl/ibmplexmono/IBMPlexMono-Medium.ttf
curl -fsSL -o assets/google_fonts/PlayfairDisplay-Black.ttf  $base/ofl/playfairdisplay/PlayfairDisplay%5Bwght%5D.ttf
curl -fsSL -o assets/google_fonts/CormorantGaramond-Medium.ttf $base/ofl/cormorantgaramond/CormorantGaramond-Medium.ttf
curl -fsSL -o assets/google_fonts/CourierPrime-Regular.ttf   $base/ofl/courierprime/CourierPrime-Regular.ttf
curl -fsSL -o assets/google_fonts/BebasNeue-Regular.ttf      $base/ofl/bebasneue/BebasNeue-Regular.ttf
curl -fsSL -o assets/google_fonts/WorkSans-Medium.ttf        $base/ofl/worksans/WorkSans%5Bwght%5D.ttf
curl -fsSL -o assets/google_fonts/RobotoMono-Medium.ttf      $base/apache/robotomono/RobotoMono%5Bwght%5D.ttf
ls -la assets/google_fonts/ | wc -l   # expect 13 lines (12 files + total)
```

If any URL 404s, find the family at `https://github.com/google/fonts` and take the static instance nearest the weight named above. Variable fonts (`Family[wght].ttf`) are acceptable — `google_fonts` handles them.

- [ ] **Step 2: Declare the asset directory**

In `app/pubspec.yaml`, under `flutter:` → `assets:`, add the directory alongside the existing entries:

```yaml
  assets:
    - assets/google_fonts/
```

Run `fvm flutter pub get`.

- [ ] **Step 3: Disable runtime fetching**

In `app/lib/main.dart`, immediately after `WidgetsFlutterBinding.ensureInitialized()`, add:

```dart
  // Fonts ship with the app: a frame that needs the network to render is a
  // frame that fails on a plane.
  GoogleFonts.config.allowRuntimeFetching = false;
```

with `import 'package:google_fonts/google_fonts.dart';` at the top.

- [ ] **Step 4: Write the failing test**

Create `app/test/core/voice_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/voice.dart';

void main() {
  test('every voice names three distinct roles', () {
    expect(kVoices.length, VoiceId.values.length);
    for (final v in kVoices.values) {
      expect({v.display, v.text, v.data}.length, 3, reason: '${v.id} reuses a family across roles');
    }
  });

  test('bias weights, never forces: a mono shot leans serif but nothing is excluded', () {
    const allowed = {VoiceId.postOffice, VoiceId.bureau, VoiceId.deco, VoiceId.civic};
    final mono = voiceWeights(filmSim: 'ACROS', iso: 400, allowed: allowed);
    final vivid = voiceWeights(filmSim: 'VELVIA', iso: 200, allowed: allowed);

    for (final w in [mono, vivid]) {
      expect(w.keys.toSet(), allowed);
      for (final v in w.values) {
        expect(v, greaterThan(0), reason: 'a bias must never zero an allowed voice');
      }
    }
    // deco is the serif voice; it must be likelier on the monochrome shot
    expect(mono[VoiceId.deco]! / mono.values.reduce((a, b) => a + b),
        greaterThan(vivid[VoiceId.deco]! / vivid.values.reduce((a, b) => a + b)));
  });

  test('only allowed voices are weighted', () {
    final w = voiceWeights(filmSim: null, iso: null, allowed: {VoiceId.civic});
    expect(w.keys.single, VoiceId.civic);
  });
}
```

- [ ] **Step 5: Run it and watch it fail**

Run: `cd app && fvm flutter test test/core/voice_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'kata/core/compose/voice.dart'`.

- [ ] **Step 6: Implement `voice.dart`**

Create `app/lib/core/compose/voice.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A frame speaks in a voice, not in a font. Each voice pairs three roles —
/// display (the numeral, the big mark), text (the country line, the caption)
/// and data (dates, codes) — so an object can be set entirely from one choice.
enum VoiceId { postOffice, bureau, deco, civic }

class Voice {
  const Voice(this.id, this.display, this.text, this.data, {this.displayWeight = FontWeight.w700, this.displayTracking = 0});

  final VoiceId id;
  final String display, text, data;
  final FontWeight displayWeight;

  /// Fraction of the font size, applied as letter spacing on display type.
  final double displayTracking;

  TextStyle displayStyle(double size, Color c) => GoogleFonts.getFont(display,
      fontSize: size, fontWeight: displayWeight, color: c, height: 1, letterSpacing: size * displayTracking);

  TextStyle textStyle(double size, Color c, {FontWeight weight = FontWeight.w500, double tracking = 0.12}) =>
      GoogleFonts.getFont(text, fontSize: size, fontWeight: weight, color: c, height: 1.1, letterSpacing: size * tracking);

  TextStyle dataStyle(double size, Color c) =>
      GoogleFonts.getFont(data, fontSize: size, fontWeight: FontWeight.w500, color: c, height: 1);
}

const kVoices = <VoiceId, Voice>{
  VoiceId.postOffice: Voice(VoiceId.postOffice, 'Oswald', 'Barlow Condensed', 'Space Mono', displayTracking: -0.03),
  VoiceId.bureau: Voice(VoiceId.bureau, 'Archivo Black', 'IBM Plex Sans', 'IBM Plex Mono'),
  VoiceId.deco: Voice(VoiceId.deco, 'Playfair Display', 'Cormorant Garamond', 'Courier Prime', displayWeight: FontWeight.w900),
  VoiceId.civic: Voice(VoiceId.civic, 'Bebas Neue', 'Work Sans', 'Roboto Mono'),
};

/// How likely each allowed voice is for this shot. Weighting, never forcing:
/// every allowed voice keeps a floor of 1, so a shuffle can still surprise.
Map<VoiceId, double> voiceWeights({required String? filmSim, required int? iso, required Set<VoiceId> allowed}) {
  final sim = (filmSim ?? '').toUpperCase();
  bool has(List<String> keys) => keys.any(sim.contains);

  final w = {for (final id in allowed) id: 1.0};
  void bump(VoiceId id, double by) {
    if (w.containsKey(id)) w[id] = w[id]! + by;
  }

  if (has(['ACROS', 'MONOCHROME', 'SEPIA'])) {
    bump(VoiceId.deco, 2.5); // high-contrast serif suits black and white
    bump(VoiceId.bureau, 0.5);
  }
  if (has(['CLASSIC NEG', 'NOSTALGIC', 'ETERNA'])) {
    bump(VoiceId.postOffice, 2.0); // warm mid-century
  }
  if (has(['CLASSIC CHROME', 'PROVIA', 'REALA'])) {
    bump(VoiceId.bureau, 2.0); // neutral, institutional
  }
  if (has(['VELVIA'])) {
    bump(VoiceId.civic, 2.0); // condensed poster
  }
  if ((iso ?? 0) >= 3200) {
    bump(VoiceId.civic, 1.0); // rough shot, heavier display
    bump(VoiceId.bureau, 0.5);
  }
  return w;
}
```

- [ ] **Step 7: Run the test**

Run: `cd app && fvm flutter test test/core/voice_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 8: Verify the fonts actually load offline**

Run: `cd app && fvm flutter analyze` (expect "No issues found!"), then:

```bash
cd app && fvm flutter test test/core/voice_test.dart 2>&1 | grep -i "http\|network" || echo "no network calls"
```

Expected: `no network calls` — with `allowRuntimeFetching = false` and bundled assets, nothing is fetched.

- [ ] **Step 9: Commit**

```bash
cd /home/parth/WebstormProjects/fuji
git add app/assets/google_fonts app/pubspec.yaml app/lib/main.dart app/lib/core/compose/voice.dart app/test/core/voice_test.dart
git commit -m "compose: voices — a frame speaks in a pairing, not a font

Four pairings of display/text/data, bundled rather than fetched so a frame
never needs the network to render. The shot weights which is drawn — a
monochrome sim leans serif, Velvia leans condensed poster — but every
allowed voice keeps a floor, so shuffling still surprises."
```

---

### Task 2: Ink — colour from the photograph, with a legibility floor

**Files:**
- Create: `app/lib/core/compose/ink.dart`
- Create: `app/test/core/ink_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `class InkFamily { const InkFamily(this.name, this.anchors); final String name; final List<Color> anchors; }`; `const kInkFamilies` map keyed by name (`'postmark'`, `'archive'`, `'lab'`); `Color pickInk({required InkFamily family, required List<Color> palette, required Color ground, required int seed})`; `double contrastRatio(Color a, Color b)`.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/ink_test.dart`:

```dart
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
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd app && fvm flutter test test/core/ink_test.dart`
Expected: FAIL — `Couldn't resolve the package 'kata/core/compose/ink.dart'`.

- [ ] **Step 3: Implement `ink.dart`**

Create `app/lib/core/compose/ink.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

/// The inks an object is printed in. A postmark is red-black; an archive label
/// is maroon-black; a lab print is cyan-black. The photograph biases the choice
/// *within* the family — it never gets to make a stamp green.
class InkFamily {
  const InkFamily(this.name, this.anchors);
  final String name;

  /// The family's poles. A drawn ink is a mix of the photo's nearest colour and
  /// one of these, so it always reads as that object's ink.
  final List<Color> anchors;
}

const kInkFamilies = <String, InkFamily>{
  'postmark': InkFamily('postmark', [Color(0xFF8C2A18), Color(0xFF2A1512), Color(0xFF6E1F14)]),
  'archive': InkFamily('archive', [Color(0xFF5B1A22), Color(0xFF1C1A18), Color(0xFF43121A)]),
  'lab': InkFamily('lab', [Color(0xFF13485C), Color(0xFF1A1A1C), Color(0xFF0E5A63)]),
};

double _lin(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _relativeLuminance(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

/// WCAG contrast ratio, 1..21.
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a), lb = _relativeLuminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Draws an ink for this object from this photograph, then forces it legible.
Color pickInk({required InkFamily family, required List<Color> palette, required Color ground, required int seed}) {
  final r = math.Random(seed);
  final anchor = family.anchors[r.nextInt(family.anchors.length)];
  // the photo's most saturated colour, if it has one worth borrowing
  Color? borrowed;
  var best = 0.0;
  for (final c in palette) {
    final mx = math.max(c.r, math.max(c.g, c.b)), mn = math.min(c.r, math.min(c.g, c.b));
    final sat = mx <= 0 ? 0.0 : (mx - mn) / mx;
    if (sat > best) {
      best = sat;
      borrowed = c;
    }
  }
  // 0.25..0.55 of the photo's colour: enough to tie the ink to the picture,
  // never enough to leave the family
  var ink = borrowed == null ? anchor : Color.lerp(anchor, borrowed, 0.25 + r.nextDouble() * 0.30)!;

  // legibility is not negotiable: darken toward the family's darkest anchor
  final darkest = family.anchors.reduce((a, b) => _relativeLuminance(a) < _relativeLuminance(b) ? a : b);
  for (var i = 0; i < 12 && contrastRatio(ink, ground) < 3.0; i++) {
    ink = Color.lerp(ink, darkest, 0.2)!;
  }
  // still failing (a dark ground): go the other way, toward the paper's light
  for (var i = 0; i < 12 && contrastRatio(ink, ground) < 3.0; i++) {
    ink = Color.lerp(ink, const Color(0xFFF6F1E6), 0.2)!;
  }
  return ink;
}
```

- [ ] **Step 4: Run the test**

Run: `cd app && fvm flutter test test/core/ink_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
cd /home/parth/WebstormProjects/fuji
git add app/lib/core/compose/ink.dart app/test/core/ink_test.dart
git commit -m "compose: ink drawn from the photograph, forced legible

Each object declares an ink family — a postmark is red-black, an archive
label maroon-black — and the photo biases the choice inside it, so the ink
ties to the picture without a stamp ever coming out green. Contrast against
the ground is then forced over 3:1, darkening toward the family or lifting
toward paper depending on which way the ground sits."
```

---

### Task 3: Treatment — the imperfection

**Files:**
- Create: `app/lib/core/compose/treatment.dart`
- Create: `app/test/core/treatment_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `class TreatmentBounds { const TreatmentBounds({this.slip = 0.012, this.bleed = 1.2, this.pressure = 0.22, this.speckles = 40, this.wear = 1.0}); }`; `class Treatment { final Offset slip; final double turn, bleed, pressure; final int speckles; final double wear; static Treatment draw(TreatmentBounds b, int seed); }`; `class SpecklePainter extends CustomPainter`; `class PressurePainter extends CustomPainter`.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/treatment_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/treatment.dart';

void main() {
  test('a drawn treatment never exceeds the bounds the frame allowed', () {
    const tight = TreatmentBounds(slip: 0.004, bleed: 0.3, pressure: 0.05, speckles: 6, wear: 0);
    for (var seed = 0; seed < 300; seed++) {
      final t = Treatment.draw(tight, seed);
      expect(t.slip.dx.abs(), lessThanOrEqualTo(0.004));
      expect(t.slip.dy.abs(), lessThanOrEqualTo(0.004));
      expect(t.bleed, inInclusiveRange(0, 0.3));
      expect(t.pressure, inInclusiveRange(0, 0.05));
      expect(t.speckles, inInclusiveRange(0, 6));
      expect(t.wear, 0, reason: 'a frame that forbids wear must never get any');
    }
  });

  test('the same seed draws the same treatment', () {
    const b = TreatmentBounds();
    expect(Treatment.draw(b, 11).slip, Treatment.draw(b, 11).slip);
    expect(Treatment.draw(b, 11).speckles, Treatment.draw(b, 11).speckles);
  });

  test('different seeds draw different treatments', () {
    const b = TreatmentBounds();
    final seen = {for (var s = 0; s < 20; s++) Treatment.draw(b, s).speckles};
    expect(seen.length, greaterThan(3), reason: 'the roll is not actually varying');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd app && fvm flutter test test/core/treatment_test.dart`
Expected: FAIL — package not resolved.

- [ ] **Step 3: Implement `treatment.dart`**

Create `app/lib/core/compose/treatment.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How far each imperfection may go on this object. A museum label allows
/// almost none; a stamp that went through the post allows plenty.
class TreatmentBounds {
  const TreatmentBounds({this.slip = 0.012, this.bleed = 1.2, this.pressure = 0.22, this.speckles = 40, this.wear = 1.0});

  /// Registration slip, as a fraction of the object's size.
  final double slip;

  /// Blur radius on printed marks, in logical pixels at preview scale.
  final double bleed;

  /// Peak density variation across the sheet, 0..1.
  final double pressure;

  /// Maximum number of specks and hairs.
  final int speckles;

  /// 0 = pristine, 1 = fully allowed wear (a torn perforation, a bent corner).
  final double wear;
}

/// One draw from those bounds.
class Treatment {
  const Treatment({required this.slip, required this.turn, required this.bleed, required this.pressure, required this.speckles, required this.wear});

  final Offset slip;

  /// Rotation of the slipped layer, radians.
  final double turn;
  final double bleed, pressure;
  final int speckles;
  final double wear;

  static const none = Treatment(slip: Offset.zero, turn: 0, bleed: 0, pressure: 0, speckles: 0, wear: 0);

  static Treatment draw(TreatmentBounds b, int seed) {
    final r = math.Random(seed);
    double sym(double max) => (r.nextDouble() * 2 - 1) * max;
    return Treatment(
      slip: Offset(sym(b.slip), sym(b.slip)),
      turn: sym(b.slip * 20), // slip and turn come from the same mis-feed
      bleed: r.nextDouble() * b.bleed,
      pressure: r.nextDouble() * b.pressure,
      speckles: b.speckles == 0 ? 0 : r.nextInt(b.speckles + 1),
      wear: r.nextDouble() * b.wear,
    );
  }
}

/// Dust, hairs and specks — the print shop wasn't clean.
class SpecklePainter extends CustomPainter {
  SpecklePainter(this.treatment, this.seed);
  final Treatment treatment;
  final int seed;

  @override
  void paint(Canvas c, Size s) {
    final r = math.Random(seed ^ 0x9E3);
    final p = Paint();
    for (var i = 0; i < treatment.speckles; i++) {
      final dark = r.nextBool();
      p.color = (dark ? Colors.black : Colors.white).withValues(alpha: 0.05 + r.nextDouble() * 0.16);
      final at = Offset(r.nextDouble() * s.width, r.nextDouble() * s.height);
      if (r.nextInt(5) == 0) {
        final path = Path()..moveTo(at.dx, at.dy);
        var q = at;
        for (var k = 0; k < 3; k++) {
          q += Offset((r.nextDouble() - 0.5) * s.width * 0.05, (r.nextDouble() - 0.5) * s.width * 0.05);
          path.lineTo(q.dx, q.dy);
        }
        c.drawPath(
            path,
            p
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.7);
      } else {
        c.drawCircle(at, 0.4 + r.nextDouble() * 1.1, p..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(SpecklePainter o) => o.seed != seed || o.treatment.speckles != treatment.speckles;
}

/// Uneven pressure: low-frequency density variation, as if the platen wasn't
/// quite flat. Painted as a few soft overlay blooms.
class PressurePainter extends CustomPainter {
  PressurePainter(this.treatment, this.seed);
  final Treatment treatment;
  final int seed;

  @override
  void paint(Canvas c, Size s) {
    if (treatment.pressure <= 0) return;
    final r = math.Random(seed ^ 0x51);
    for (var i = 0; i < 5; i++) {
      final centre = Offset(r.nextDouble() * s.width, r.nextDouble() * s.height);
      final radius = s.width * (0.35 + r.nextDouble() * 0.4);
      c.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white.withValues(alpha: treatment.pressure * 0.5), Colors.white.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: centre, radius: radius))
          ..blendMode = BlendMode.overlay,
      );
    }
  }

  @override
  bool shouldRepaint(PressurePainter o) => o.seed != seed || o.treatment.pressure != treatment.pressure;
}
```

- [ ] **Step 4: Run the test**

Run: `cd app && fvm flutter test test/core/treatment_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
cd /home/parth/WebstormProjects/fuji
git add app/lib/core/compose/treatment.dart app/test/core/treatment_test.dart
git commit -m "compose: treatment — the imperfection, bounded per object

Registration slip, bleed, uneven pressure, speckle and wear, drawn from one
seed inside bounds the object declares: a museum label allows almost none, a
stamp that went through the post allows plenty. A frame that forbids wear can
never be given any, which the fuzz test pins across 300 seeds."
```

---

### Task 4: Roll — the seeded draw, with pins

**Files:**
- Create: `app/lib/core/compose/roll.dart`
- Create: `app/test/core/roll_test.dart`

**Interfaces:**
- Consumes: `voice.dart` (`VoiceId`, `voiceWeights`), `ink.dart` (`InkFamily`, `pickInk`), `treatment.dart` (`TreatmentBounds`, `Treatment`).
- Produces: `enum RollAxis { object, voice, ink, treatment }`; `class Allowances { const Allowances({required this.voices, required this.inkFamily, required this.treatment, this.grounds = const []}); }`; `class Roll { final int seed; final VoiceId voiceId; final Voice voice; final Color ink, ground; final Treatment treatment; static Roll draw({required int seed, required Allowances allowances, required List<Color> palette, String? filmSim, int? iso, Roll? pinnedFrom, Set<RollAxis> pins = const {}}); }`.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/roll_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/ink.dart';
import 'package:kata/core/compose/roll.dart';
import 'package:kata/core/compose/treatment.dart';
import 'package:kata/core/compose/voice.dart';

const _allowances = Allowances(
  voices: {VoiceId.postOffice, VoiceId.civic},
  inkFamily: 'postmark',
  treatment: TreatmentBounds(),
  grounds: [Color(0xFF7E2418), Color(0xFF1F3D34)],
);

const _palette = [Color(0xFF8A2B1C), Color(0xFF3C4A5A), Color(0xFFE8DFC9)];

Roll _roll(int seed, {Roll? from, Set<RollAxis> pins = const {}}) => Roll.draw(
      seed: seed,
      allowances: _allowances,
      palette: _palette,
      filmSim: 'CLASSIC CHROME',
      iso: 400,
      pinnedFrom: from,
      pins: pins,
    );

void main() {
  test('the same seed is the same output', () {
    final a = _roll(7), b = _roll(7);
    expect(a.voiceId, b.voiceId);
    expect(a.ink, b.ink);
    expect(a.ground, b.ground);
    expect(a.treatment.slip, b.treatment.slip);
  });

  test('a roll never leaves the allowances', () {
    for (var seed = 0; seed < 400; seed++) {
      final r = _roll(seed);
      expect(_allowances.voices.contains(r.voiceId), isTrue, reason: 'seed $seed drew a forbidden voice');
      expect(_allowances.grounds.contains(r.ground), isTrue, reason: 'seed $seed drew a forbidden ground');
      expect(contrastRatio(r.ink, r.ground), greaterThanOrEqualTo(3.0), reason: 'seed $seed is unreadable');
    }
  });

  test('seeds actually vary the draw', () {
    final voices = {for (var s = 0; s < 40; s++) _roll(s).voiceId};
    expect(voices.length, greaterThan(1));
  });

  test('a pinned axis holds while the others move', () {
    final first = _roll(1);
    var movedVoice = false, movedInk = false;
    for (var seed = 2; seed < 40; seed++) {
      final next = _roll(seed, from: first, pins: {RollAxis.voice});
      expect(next.voiceId, first.voiceId, reason: 'the pinned voice changed at seed $seed');
      if (next.ink != first.ink) movedInk = true;
      if (next.treatment.slip != first.treatment.slip) movedVoice = true;
    }
    expect(movedInk, isTrue, reason: 'pinning the voice froze the ink too');
    expect(movedVoice, isTrue, reason: 'pinning the voice froze the treatment too');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd app && fvm flutter test test/core/roll_test.dart`
Expected: FAIL — package not resolved.

- [ ] **Step 3: Implement `roll.dart`**

Create `app/lib/core/compose/roll.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'ink.dart';
import 'treatment.dart';
import 'voice.dart';

/// The axes a shuffle may move. Each can be pinned independently, which is what
/// keeps this a tool rather than a slot machine.
enum RollAxis { object, voice, ink, treatment }

/// What an object permits the roll to touch.
class Allowances {
  const Allowances({required this.voices, required this.inkFamily, required this.treatment, this.grounds = const []});

  final Set<VoiceId> voices;

  /// A key into [kInkFamilies].
  final String inkFamily;
  final TreatmentBounds treatment;

  /// The grounds this object may be mounted on. Empty = the object supplies its
  /// own and the roll doesn't choose.
  final List<Color> grounds;
}

/// One seeded draw. Reproducible from (seed, allowances, palette, shot).
class Roll {
  const Roll({required this.seed, required this.voiceId, required this.voice, required this.ink, required this.ground, required this.treatment});

  final int seed;
  final VoiceId voiceId;
  final Voice voice;
  final Color ink, ground;
  final Treatment treatment;

  static Roll draw({
    required int seed,
    required Allowances allowances,
    required List<Color> palette,
    String? filmSim,
    int? iso,
    Roll? pinnedFrom,
    Set<RollAxis> pins = const {},
  }) {
    // separate streams per axis: pinning one must not shift the others
    final voiceRnd = math.Random(seed * 31 + 1);
    final groundRnd = math.Random(seed * 31 + 3);

    VoiceId voiceId;
    if (pins.contains(RollAxis.voice) && pinnedFrom != null) {
      voiceId = pinnedFrom.voiceId;
    } else {
      final weights = voiceWeights(filmSim: filmSim, iso: iso, allowed: allowances.voices);
      final total = weights.values.fold(0.0, (a, b) => a + b);
      var pick = voiceRnd.nextDouble() * total;
      voiceId = weights.keys.first;
      for (final e in weights.entries) {
        pick -= e.value;
        if (pick <= 0) {
          voiceId = e.key;
          break;
        }
      }
    }

    final ground = allowances.grounds.isEmpty
        ? const Color(0xFF1A1714)
        : (pins.contains(RollAxis.ink) && pinnedFrom != null
            ? pinnedFrom.ground
            : allowances.grounds[groundRnd.nextInt(allowances.grounds.length)]);

    final ink = pins.contains(RollAxis.ink) && pinnedFrom != null
        ? pinnedFrom.ink
        : pickInk(family: kInkFamilies[allowances.inkFamily]!, palette: palette, ground: ground, seed: seed * 31 + 5);

    final treatment = pins.contains(RollAxis.treatment) && pinnedFrom != null
        ? pinnedFrom.treatment
        : Treatment.draw(allowances.treatment, seed * 31 + 7);

    return Roll(seed: seed, voiceId: voiceId, voice: kVoices[voiceId]!, ink: ink, ground: ground, treatment: treatment);
  }
}
```

- [ ] **Step 4: Run the test**

Run: `cd app && fvm flutter test test/core/roll_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
cd /home/parth/WebstormProjects/fuji
git add app/lib/core/compose/roll.dart app/test/core/roll_test.dart
git commit -m "compose: the roll — one seed, three axes, independent pins

Voice, ink and treatment are drawn from separate random streams off the one
seed, so pinning an axis holds it without shifting the others. Fuzzed over
400 seeds: a roll never leaves the object's allowances and never produces
ink below 3:1 on its ground."
```

---

### Task 5: The object contract

**Files:**
- Create: `app/lib/features/waku/frames/frame.dart`
- Create: `app/test/features/frames_test.dart`

**Interfaces:**
- Consumes: `roll.dart`, `layers.dart`, `sheet_layout.dart`, `waku_exif.dart` (`PhotoMeta`), `waku_grain_measure.dart` (`PhotoGrain`).
- Produces: `class ObjectContext { final Size size; final PhotoMeta meta; final PhotoGrain grain; final List<Color> palette; final Roll roll; final String? kataName; }`; `abstract class WakuObject { String get id; String get label; Allowances get allowances; List<ComposeLayer> build(ObjectContext ctx); }`; `const List<WakuObject> kObjects` (populated by later tasks); `WakuObject objectById(String id)`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/frames_test.dart`. It fuzzes every registered object across seeds and ratios — the contract every object must keep:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/layers.dart';
import 'package:kata/core/compose/roll.dart';
import 'package:kata/features/waku/frames/frame.dart';
import 'package:kata/features/waku/waku_exif.dart';
import 'package:kata/features/waku/waku_grain_measure.dart';

const _palette = [Color(0xFF8A2B1C), Color(0xFF3C4A5A), Color(0xFFE8DFC9), Color(0xFF6B7F52), Color(0xFFD8C9A8)];
const _meta = PhotoMeta(model: 'X-S20', iso: 400, filmMode: 'CLASSIC CHROME');
const _ratios = [(600.0, 750.0), (600.0, 600.0), (600.0, 1067.0), (600.0, 900.0)];

void main() {
  test('the registry is not empty', () {
    expect(kObjects, isNotEmpty);
  });

  test('every object keeps its slots on the sheet, at every ratio and seed', () {
    for (final obj in kObjects) {
      for (final (w, h) in _ratios) {
        final size = Size(w, h);
        for (var seed = 0; seed < 25; seed++) {
          final roll = Roll.draw(seed: seed, allowances: obj.allowances, palette: _palette, filmSim: _meta.filmMode, iso: _meta.iso);
          final layers = obj.build(ObjectContext(
            size: size,
            meta: _meta,
            grain: PhotoGrain.none,
            palette: _palette,
            roll: roll,
          ));
          expect(layers, isNotEmpty, reason: '${obj.id} built nothing');
          final sheet = Rect.fromLTWH(0, 0, w, h);
          for (final l in layers) {
            if (l is ComposeTextSlot) {
              expect(sheet.contains(l.region.topLeft) || sheet.overlaps(l.region), isTrue,
                  reason: '${obj.id} put slot ${l.id} off the sheet at ${w}x$h seed $seed');
              expect(l.region.width, greaterThan(0), reason: '${obj.id} slot ${l.id} has no width');
            }
            if (l is ComposePhotoWindow) {
              expect(l.rect.width, greaterThan(0));
              expect(l.rect.height, greaterThan(0));
            }
          }
          expect(layers.whereType<ComposePhotoWindow>().length, 1, reason: '${obj.id} must have exactly one photo window');
        }
      }
    }
  });

  test('object ids are unique and resolvable', () {
    expect(kObjects.map((o) => o.id).toSet().length, kObjects.length);
    for (final o in kObjects) {
      expect(objectById(o.id), same(o));
    }
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd app && fvm flutter test test/features/frames_test.dart`
Expected: FAIL — package not resolved.

- [ ] **Step 3: Implement `frame.dart`**

Create `app/lib/features/waku/frames/frame.dart`:

```dart
import 'dart:ui';

import '../../../core/compose/layers.dart';
import '../../../core/compose/roll.dart';
import '../waku_exif.dart';
import '../waku_grain_measure.dart';

/// Everything an object needs to build itself for one output.
class ObjectContext {
  const ObjectContext({
    required this.size,
    required this.meta,
    required this.grain,
    required this.palette,
    required this.roll,
    this.kataName,
    this.kataCode,
  });

  final Size size;
  final PhotoMeta meta;
  final PhotoGrain grain;
  final List<Color> palette;
  final Roll roll;

  /// The attached recipe's name, when there is one.
  final String? kataName;

  /// The `kata1:` payload, for the object's code furniture.
  final String? kataCode;
}

/// A printed object. Identity and slots are authored here; only [allowances]
/// may be rolled (see docs/design/waku-spec.md §3).
abstract class WakuObject {
  const WakuObject();

  /// Stable id, used for pinning and for the frames drawer.
  String get id;

  /// What the drawer calls it.
  String get label;

  /// What the roll may touch.
  Allowances get allowances;

  /// The layer stack for one output. Must contain exactly one
  /// [ComposePhotoWindow], and every [ComposeTextSlot] must lie on the sheet.
  List<ComposeLayer> build(ObjectContext ctx);
}

/// Every object the app can produce. Tasks 6, 8 and 9 add to this.
const List<WakuObject> kObjects = [];

WakuObject objectById(String id) => kObjects.firstWhere((o) => o.id == id, orElse: () => kObjects.first);
```

- [ ] **Step 4: Run the test**

Run: `cd app && fvm flutter test test/features/frames_test.dart`
Expected: FAIL on the first test — `Expected: not empty / Actual: []`. That is correct: the registry is genuinely empty until Task 6. Leave it failing and mark the test `skip: 'no objects until Task 6'` on the two fuzz tests only:

```dart
  test('every object keeps its slots on the sheet, at every ratio and seed', skip: 'no objects registered until Task 6', () async {
```

Re-run: the registry test still fails. Change it to assert the shape instead, so this task commits green:

```dart
  test('the registry exists and ids resolve', () {
    expect(kObjects, isA<List<WakuObject>>());
  });
```

Delete the `object ids are unique` test for now; Task 6 restores it with real objects.

- [ ] **Step 5: Run the test again**

Run: `cd app && fvm flutter test test/features/frames_test.dart`
Expected: PASS (1 test, 1 skipped).

- [ ] **Step 6: Commit**

```bash
cd /home/parth/WebstormProjects/fuji
git add app/lib/features/waku/frames/frame.dart app/test/features/frames_test.dart
git commit -m "waku: the object contract — identity and slots authored, allowances rolled

A WakuObject declares what it is (id, label), what the roll may touch
(allowances) and how to build one output from a context carrying the shot,
its grain, its palette and the roll. The fuzz test that every object must
pass — one photo window, every slot on the sheet, at four ratios across 25
seeds — lands with it, skipped until there is an object to run it against."
```

---

### Task 6: The postage stamp

**Files:**
- Create: `app/lib/features/waku/frames/stamp.dart`
- Create: `app/lib/features/waku/dev_roll_grid.dart`
- Modify: `app/lib/features/waku/frames/frame.dart` (register the object)
- Modify: `app/test/features/frames_test.dart` (un-skip the fuzz tests)
- Delete: `app/lib/scratch_stamp.dart`

**Interfaces:**
- Consumes: `frame.dart` (`WakuObject`, `ObjectContext`), `roll.dart`, `treatment.dart`, `layers.dart`.
- Produces: `class StampObject extends WakuObject` with `id == 'stamp'`; `class PerforationClipper extends CustomClipper<Path>`; `class PostmarkPainter extends CustomPainter`; `class DevRollGrid extends StatefulWidget`.

- [ ] **Step 1: Write the failing test**

In `app/test/features/frames_test.dart`, remove the two `skip:` arguments and restore the id test:

```dart
  test('object ids are unique and resolvable', () {
    expect(kObjects.map((o) => o.id).toSet().length, kObjects.length);
    for (final o in kObjects) {
      expect(objectById(o.id), same(o));
    }
  });

  test('the stamp is registered', () {
    expect(kObjects.any((o) => o.id == 'stamp'), isTrue);
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd app && fvm flutter test test/features/frames_test.dart`
Expected: FAIL — `the stamp is registered` fails, and the fuzz test fails on the empty registry.

- [ ] **Step 3: Implement the stamp**

Create `app/lib/features/waku/frames/stamp.dart`. The perforation clipper and postmark painter below are ported from the proven spike (`lib/scratch_stamp.dart`, deleted in Step 7):

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/compose/grain.dart';
import '../../../core/compose/layers.dart';
import '../../../core/compose/roll.dart';
import '../../../core/compose/treatment.dart';
import '../../../core/compose/voice.dart';
import 'frame.dart';

/// A postage stamp, mounted on a card. Identity: the perforated edge, the white
/// margin, the corner denomination, and a postmark that laps off the stamp onto
/// the mount because the clerk wasn't aiming.
class StampObject extends WakuObject {
  const StampObject();

  @override
  String get id => 'stamp';

  @override
  String get label => 'Stamp';

  @override
  Allowances get allowances => const Allowances(
        voices: {VoiceId.postOffice, VoiceId.bureau, VoiceId.civic},
        inkFamily: 'postmark',
        treatment: TreatmentBounds(slip: 0.014, bleed: 1.3, pressure: 0.26, speckles: 40, wear: 1),
        grounds: [Color(0xFF7E2418), Color(0xFF1F3D34), Color(0xFF23324D), Color(0xFF4A3C22), Color(0xFF12100E)],
      );

  @override
  List<ComposeLayer> build(ObjectContext ctx) {
    final s = ctx.size;
    final roll = ctx.roll;
    // the stamp sits on its mount, a little above centre like a specimen
    final stampW = s.width * 0.72;
    final stampH = stampW * 1.26;
    final stamp = Rect.fromLTWH((s.width - stampW) / 2, s.height * 0.46 - stampH / 2, stampW, stampH);
    final face = stamp.deflate(stampW * 0.085);
    final photoRect = Rect.fromLTRB(face.left, stamp.top + stampH * 0.13, face.right, stamp.bottom - stampH * 0.155);
    final (clump, amount) = ctx.grain.onSheet(photoRect.width);

    return [
      ComposeSurface(ColoredBox(color: roll.ground)),
      ComposeGrainSheet(GrainSpec.measured(clumpPx: clump, amount: amount, seed: roll.seed)),
      ComposeSurface(CustomPaint(painter: PressurePainter(roll.treatment, roll.seed))),
      // the stamp's paper, perforated
      ComposeSurface(Padding(
        padding: EdgeInsets.fromLTRB(stamp.left, stamp.top, s.width - stamp.right, s.height - stamp.bottom),
        child: ClipPath(
          clipper: PerforationClipper(roll.treatment, roll.seed),
          child: const ColoredBox(color: Color(0xFFF4EFE3)),
        ),
      )),
      ComposePhotoWindow(rect: photoRect),
      // country line: the film simulation is what this stamp was issued by
      ComposeTextSlot(
        id: 'country',
        region: Rect.fromLTRB(face.left, stamp.top + stampH * 0.035, face.right, stamp.top + stampH * 0.125),
        style: roll.voice.textStyle(stampW * 0.062, roll.ink, tracking: 0.14),
        invitation: 'KATA',
        prefill: ctx.kataName ?? ctx.meta.filmMode,
        align: Alignment.center,
        maxChars: 22,
        fitRegion: true,
      ),
      // denomination: the ISO the shot was taken at
      ComposeTextSlot(
        id: 'denomination',
        region: Rect.fromLTRB(face.left, stamp.bottom - stampH * 0.15, face.left + face.width * 0.5, stamp.bottom - stampH * 0.02),
        style: roll.voice.displayStyle(stampW * 0.20, roll.ink),
        invitation: '400',
        prefill: ctx.meta.iso == null ? null : '${ctx.meta.iso}',
        align: Alignment.bottomLeft,
        maxChars: 6,
        fitRegion: true,
      ),
      ComposeTextSlot(
        id: 'issue',
        region: Rect.fromLTRB(face.left + face.width * 0.5, stamp.bottom - stampH * 0.13, face.right, stamp.bottom - stampH * 0.03),
        style: roll.voice.dataStyle(stampW * 0.062, roll.ink.withValues(alpha: 0.85)),
        invitation: 'ISO',
        prefill: _issueLine(ctx),
        align: Alignment.bottomRight,
        maxChars: 14,
        fitRegion: true,
      ),
      // the postmark is a second pass, so it slips and it laps onto the mount
      ComposeSurface(CustomPaint(painter: PostmarkPainter(roll, stamp, ctx.meta))),
      ComposeSurface(CustomPaint(painter: SpecklePainter(roll.treatment, roll.seed))),
      ComposeGrainSheet(GrainSpec.measured(clumpPx: clump, amount: amount * 0.33, seed: roll.seed), overInk: true),
    ];
  }

  static String? _issueLine(ObjectContext ctx) {
    final d = ctx.meta.dateTime;
    if (d == null) return null;
    return '${d.year}';
  }
}

/// Punches perforations out of the stamp's rectangle. Gauge ~13; a tooth or two
/// may fail to tear, which is what [Treatment.wear] buys.
class PerforationClipper extends CustomClipper<Path> {
  PerforationClipper(this.treatment, this.seed);
  final Treatment treatment;
  final int seed;

  @override
  Path getClip(Size size) {
    final pitch = size.width / 13;
    final r = pitch * 0.30;
    final missing = (treatment.wear * 3).floor();
    final holes = Path();
    void row(int n, Offset Function(int) at) {
      for (var i = 0; i <= n; i++) {
        if (missing > 0 && i % 7 == missing) continue;
        holes.addOval(Rect.fromCircle(center: at(i), radius: r));
      }
    }

    final nx = math.max(1, (size.width / pitch).floor());
    final ny = math.max(1, (size.height / pitch).floor());
    row(nx, (i) => Offset(i * size.width / nx, 0));
    row(nx, (i) => Offset(i * size.width / nx, size.height));
    row(ny, (i) => Offset(0, i * size.height / ny));
    row(ny, (i) => Offset(size.width, i * size.height / ny));
    return Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), holes);
  }

  @override
  bool shouldReclip(PerforationClipper o) => o.seed != seed;
}

/// The circular date stamp: arced place text, a date slug, wavy killer bars.
class PostmarkPainter extends CustomPainter {
  PostmarkPainter(this.roll, this.stamp, this.meta);
  final Roll roll;
  final Rect stamp;
  final dynamic meta; // PhotoMeta; typed loosely to keep this painter portable

  @override
  void paint(Canvas c, Size s) {
    final ink = roll.ink;
    final t = roll.treatment;
    final radius = stamp.width * 0.21;
    final centre = stamp.topLeft + Offset(stamp.width * (0.13 + t.slip.dx * 8), stamp.height * (0.14 + t.slip.dy * 8));

    c.save();
    c.translate(centre.dx, centre.dy);
    c.rotate(t.turn);
    final stroke = Paint()
      ..color = ink.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.05
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.01, t.bleed * 0.35));
    c.drawCircle(Offset.zero, radius, stroke);
    c.drawCircle(Offset.zero, radius * 0.80, stroke..strokeWidth = radius * 0.028);

    final model = (meta.model as String?) ?? 'FUJIFILM';
    _arc(c, model.toUpperCase(), radius * 0.90, -math.pi * 0.72, roll.voice.dataStyle(radius * 0.22, ink), true);
    final d = (meta.dateTime as DateTime?) ?? DateTime(2026);
    final date = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year % 100}';
    final tp = TextPainter(text: TextSpan(text: date, style: roll.voice.dataStyle(radius * 0.26, ink)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    c.restore();

    final bars = Paint()
      ..color = ink.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.055
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.01, t.bleed * 0.4));
    final gap = radius * 0.24;
    for (var i = 0; i < 5; i++) {
      final path = Path();
      final y0 = centre.dy - radius * 0.5 + i * gap;
      for (var x = 0.0; x <= stamp.width * 0.72; x += 4) {
        final y = y0 + math.sin((x / stamp.width) * math.pi * 3 + i) * radius * 0.045;
        final p = Offset(centre.dx + x - radius * 0.2, y);
        if (x == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      c.drawPath(path, bars);
    }
  }

  void _arc(Canvas c, String text, double r, double startAngle, TextStyle style, bool outward) {
    var angle = startAngle;
    for (final ch in text.split('')) {
      final tp = TextPainter(text: TextSpan(text: ch, style: style), textDirection: TextDirection.ltr)..layout();
      final step = (tp.width * 1.25) / r;
      c.save();
      c.rotate(angle + step / 2);
      c.translate(0, outward ? -r : r);
      if (!outward) c.rotate(math.pi);
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      c.restore();
      angle += step;
    }
  }

  @override
  bool shouldRepaint(PostmarkPainter o) => o.roll.seed != roll.seed;
}
```

- [ ] **Step 4: Register it**

In `app/lib/features/waku/frames/frame.dart`, replace the empty registry:

```dart
const List<WakuObject> kObjects = [StampObject()];
```

and add `import 'stamp.dart';` at the top.

- [ ] **Step 5: Run the tests**

Run: `cd app && fvm flutter test test/features/frames_test.dart`
Expected: PASS, 4 tests — including the fuzz across 4 ratios × 25 seeds.

- [ ] **Step 6: Build the eyeball harness**

Create `app/lib/features/waku/dev_roll_grid.dart` — a dev-only screen that renders nine rolls of one object so a human can judge what tests can't:

```dart
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/compose/layers.dart';
import '../../core/compose/roll.dart';
import 'frames/frame.dart';
import 'waku_exif.dart';
import 'waku_grain_measure.dart';

/// Nine rolls of one object, for judging variety and craft at a glance. Not
/// reachable from the app's navigation — run it from a debug entry point.
class DevRollGrid extends StatefulWidget {
  const DevRollGrid({super.key, required this.photo, required this.meta, required this.palette, required this.grain, required this.object});

  final Uint8List photo;
  final PhotoMeta meta;
  final List<Color> palette;
  final PhotoGrain grain;
  final WakuObject object;

  @override
  State<DevRollGrid> createState() => _DevRollGridState();
}

class _DevRollGridState extends State<DevRollGrid> {
  int _base = 1;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0E0E0E),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => setState(() => _base += 9),
          label: const Text('shuffle'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 4 / 5,
            children: [
              for (var i = 0; i < 9; i++)
                LayoutBuilder(builder: (context, box) {
                  final size = box.biggest;
                  final roll = Roll.draw(
                    seed: _base + i,
                    allowances: widget.object.allowances,
                    palette: widget.palette,
                    filmSim: widget.meta.filmMode,
                    iso: widget.meta.iso,
                  );
                  return ComposeCanvasView(
                    canvasSize: size,
                    grain: true,
                    layers: widget.object.build(ObjectContext(
                      size: size,
                      meta: widget.meta,
                      grain: widget.grain,
                      palette: widget.palette,
                      roll: roll,
                    )),
                    photo: Image.memory(widget.photo, fit: BoxFit.cover),
                    textOf: (_) => '',
                    dragOf: (_) => Offset.zero,
                    editingId: null,
                    hideInvitations: true,
                    onTapText: (_) {},
                    onDragText: (_, _) {},
                    editorBuilder: (_, _, _) => const SizedBox.shrink(),
                  );
                }),
            ],
          ),
        ),
      );
}
```

- [ ] **Step 7: Delete the spike and verify the whole suite**

```bash
cd /home/parth/WebstormProjects/fuji
rm app/lib/scratch_stamp.dart
cd app && fvm flutter analyze && fvm flutter test
```
Expected: analyze clean, all tests pass.

- [ ] **Step 8: Commit**

```bash
cd /home/parth/WebstormProjects/fuji
git add app/lib/features/waku/frames/stamp.dart app/lib/features/waku/frames/frame.dart app/lib/features/waku/dev_roll_grid.dart app/test/features/frames_test.dart
git rm --cached app/lib/scratch_stamp.dart 2>/dev/null; true
git add -A
git commit -m "waku: the postage stamp — the first real object

Perforated edge, white margin, the film simulation as the country line, the
ISO as the denomination, and a postmark that slips and laps off onto the
mount because the clerk wasn't aiming. Identity is authored; voice, ink,
ground and treatment come off the roll.

Fuzzed at four ratios across 25 seeds: one photo window, every slot on the
sheet. The dev grid renders nine rolls at once for the judgement tests can't
make, and the spike it was ported from is deleted."
```

---

### Task 7: The screen — one result, shuffle, pins

**Files:**
- Modify: `app/lib/features/waku/waku_screen.dart` (rewrite the frame-selection half)
- Modify: `app/test/features/waku_test.dart` (rewrite)
- Delete: `app/lib/features/waku/waku_frames.dart`

**Interfaces:**
- Consumes: `frame.dart` (`kObjects`, `ObjectContext`, `WakuObject`), `roll.dart` (`Roll`, `RollAxis`).
- Produces: the screen. No new public API.

- [ ] **Step 1: Write the failing test**

Rewrite `app/test/features/waku_test.dart`, keeping the existing `_png` and `_pump` helpers at the top of the current file and replacing the frame-specific tests with:

```dart
  testWidgets('a photo lands on a finished object, not a gallery', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF667788))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    // no "pick a frame" step: something is already composed
    expect(find.byType(ComposeCanvasView), findsWidgets);
    expect(find.text('SHUFFLE'), findsOneWidget);
  });

  testWidgets('shuffle changes the output; a pinned axis holds', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF667788))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));

    int seedOf(WidgetTester t) => t.state<WakuScreenState>(find.byType(WakuScreen)).roll.seed;
    final before = seedOf(t);
    await t.tap(find.text('SHUFFLE'));
    await t.pumpAndSettle();
    expect(seedOf(t), isNot(before));

    // pin the voice, then shuffle: the voice must not move
    final voiceBefore = t.state<WakuScreenState>(find.byType(WakuScreen)).roll.voiceId;
    await t.tap(find.byKey(const ValueKey('pin-voice')));
    await t.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await t.tap(find.text('SHUFFLE'));
      await t.pumpAndSettle();
    }
    expect(t.state<WakuScreenState>(find.byType(WakuScreen)).roll.voiceId, voiceBefore);
  });

  testWidgets('grain is the frame\'s own — no user controls for it anywhere', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF667788))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    expect(find.text('GRAIN'), findsNothing);
    expect(find.text('WEAK'), findsNothing);
    expect(find.text('STRONG'), findsNothing);
  });
```

Delete the tests that referenced the retired frames: `poster frame: fixed credit grid…`, `words frame: the dictionary grid…`, `a title that sizes itself…` (its behaviour is covered by `fitRegion` in `frames_test`), and the ratio-chip assertions.

- [ ] **Step 2: Run it and watch it fail**

Run: `cd app && fvm flutter test test/features/waku_test.dart`
Expected: FAIL — `WakuScreenState` is not exported and `SHUFFLE` is not found.

- [ ] **Step 3: Rewrite the screen's state**

In `app/lib/features/waku/waku_screen.dart`:

1. Rename `_WakuScreenState` to `WakuScreenState` (public, so the test can read the roll) and update `createState()`.
2. Delete the `WakuFrame`/`_frame`/`_frameThumb`/`_ratio` machinery and the `import 'waku_frames.dart';`.
3. Add this state and behaviour:

```dart
  WakuObject _object = kObjects.first;
  Roll _roll = Roll.draw(seed: 1, allowances: kObjects.first.allowances, palette: const []);
  final Set<RollAxis> _pins = {};
  int _seed = 1;

  /// What the tests read.
  Roll get roll => _roll;

  void _reroll({int? seed}) {
    setState(() {
      _seed = seed ?? (_seed + 1);
      if (!_pins.contains(RollAxis.object) && kObjects.length > 1) {
        _object = kObjects[math.Random(_seed * 17).nextInt(kObjects.length)];
      }
      _roll = Roll.draw(
        seed: _seed,
        allowances: _object.allowances,
        palette: _palette ?? const [],
        filmSim: _meta.filmMode,
        iso: _meta.iso,
        pinnedFrom: _roll,
        pins: _pins,
      );
    });
  }

  void _togglePin(RollAxis axis) => setState(() => _pins.contains(axis) ? _pins.remove(axis) : _pins.add(axis));
```

4. Replace `_layers(Size)` with:

```dart
  List<ComposeLayer> _layers(Size size) => _object.build(ObjectContext(
        size: size,
        meta: _meta,
        grain: _grain,
        palette: _palette ?? const [],
        roll: _roll,
      ));
```

5. After a photo is picked (in `_pickPhoto`, inside the existing `setState`), call `_reroll(seed: DateTime.now().millisecondsSinceEpoch % 100000);` so a fresh photo lands on a fresh object.

- [ ] **Step 4: Replace the frame gallery with shuffle and pins**

In `_controls(KataPalette p)`, delete the `Frame` section (the `ListView.separated` of `_frameThumb`) and put this in its place:

```dart
        const SizedBox(height: 16),
        KataPillButton(label: 'Shuffle', height: 46, onPressed: _photo == null ? null : () => _reroll()),
        const SizedBox(height: 10),
        KataSectionHeader('Keep'),
        const SizedBox(height: 8),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final (axis, label) in const [
            (RollAxis.object, 'Object'),
            (RollAxis.voice, 'Type'),
            (RollAxis.ink, 'Colour'),
            (RollAxis.treatment, 'Wear'),
          ])
            KataChip(
              key: ValueKey('pin-${axis.name}'),
              label: label,
              selected: _pins.contains(axis),
              onTap: () => _togglePin(axis),
            ),
        ]),
        const SizedBox(height: 6),
        Text('Shuffle re-rolls everything you haven’t kept.', style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.4)),
        const SizedBox(height: 16),
        KataSectionHeader('Object'),
        const SizedBox(height: 8),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final o in kObjects)
            KataChip(
              label: o.label,
              selected: _object.id == o.id,
              onTap: () => setState(() {
                _object = o;
                _pins.add(RollAxis.object);
                _reroll();
              }),
            ),
        ]),
```

- [ ] **Step 5: Delete the retired frames**

```bash
cd /home/parth/WebstormProjects/fuji
rm app/lib/features/waku/waku_frames.dart
cd app && fvm flutter analyze
```
Expected: errors only where `waku_frames.dart` was imported. Fix each by deleting the import and any remaining reference (`WakuFrame`, `polaroidLayers`, `posterLayers`, `wordsLayers`, `fitPhotoRect`, `hangPhotoRect`, `sheetGrain`). `hangInto` in `sheet_layout.dart` replaces `hangPhotoRect`; `sheetGrain`'s logic now lives in each object's `build`.

- [ ] **Step 6: Run the tests**

Run: `cd app && fvm flutter analyze && fvm flutter test`
Expected: analyze clean; all tests pass.

- [ ] **Step 7: Commit**

```bash
cd /home/parth/WebstormProjects/fuji
git add -A
git commit -m "waku: one finished object, a shuffle, and pins

The gallery asked you to choose an object before you could see what it would
look like with your photo in it. Now a photo lands on something already
composed, Shuffle re-rolls it, and each axis — object, type, colour, wear —
can be kept while the rest move, so you converge instead of gambling.

Polaroid, poster and words are deleted. They were layouts; the spec calls
for objects, and retrofitting would have carried the compromise forward."
```

---

### Task 8: The 35mm negative strip

**Files:**
- Create: `app/lib/features/waku/frames/negative_strip.dart`
- Modify: `app/lib/features/waku/frames/frame.dart` (register)

**Interfaces:**
- Consumes: `frame.dart`, `roll.dart`, `layers.dart`, `treatment.dart`.
- Produces: `class NegativeStripObject extends WakuObject` with `id == 'negative'`.

- [ ] **Step 1: Write the failing test**

Add to `app/test/features/frames_test.dart`:

```dart
  test('the negative strip is registered and carries the recipe on its edge', () {
    final obj = kObjects.firstWhere((o) => o.id == 'negative');
    final layers = obj.build(ObjectContext(
      size: const Size(600, 750),
      meta: _meta,
      grain: PhotoGrain.none,
      palette: _palette,
      roll: Roll.draw(seed: 3, allowances: obj.allowances, palette: _palette),
      kataName: 'KODACHROME 64',
    ));
    final edge = layers.whereType<ComposeTextSlot>().firstWhere((s) => s.id == 'stock');
    expect(edge.prefill, contains('KODACHROME 64'));
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd app && fvm flutter test test/features/frames_test.dart`
Expected: FAIL — `Bad state: No element` (no object with id `negative`).

- [ ] **Step 3: Implement the negative strip**

Create `app/lib/features/waku/frames/negative_strip.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/compose/grain.dart';
import '../../../core/compose/layers.dart';
import '../../../core/compose/roll.dart';
import '../../../core/compose/treatment.dart';
import '../../../core/compose/voice.dart';
import 'frame.dart';

/// A 35mm negative strip on a light table. Identity: rounded-rect sprockets at
/// 4.75 mm pitch (round holes are the giveaway of a fake), the edge print above
/// them carrying the stock — which here is the recipe — and frame numbers with
/// their arrows below.
class NegativeStripObject extends WakuObject {
  const NegativeStripObject();

  @override
  String get id => 'negative';

  @override
  String get label => 'Negative';

  @override
  Allowances get allowances => const Allowances(
        voices: {VoiceId.bureau, VoiceId.civic, VoiceId.postOffice},
        inkFamily: 'lab',
        // a strip in a sleeve stays cleaner than a stamp in the post
        treatment: TreatmentBounds(slip: 0.005, bleed: 0.6, pressure: 0.12, speckles: 22, wear: 0.4),
        grounds: [Color(0xFF14161A), Color(0xFF101418), Color(0xFF1A1614)],
      );

  @override
  List<ComposeLayer> build(ObjectContext ctx) {
    final s = ctx.size;
    final roll = ctx.roll;
    // the strip runs the full width; the frame sits in the middle band
    final stripH = s.height * 0.52;
    final strip = Rect.fromLTWH(0, (s.height - stripH) / 2, s.width, stripH);
    final sprocketBand = stripH * 0.17;
    final photoRect = Rect.fromLTRB(s.width * 0.06, strip.top + sprocketBand, s.width * 0.94, strip.bottom - sprocketBand);
    final (clump, amount) = ctx.grain.onSheet(photoRect.width);
    final stockLine = [ctx.kataName ?? ctx.meta.filmMode ?? 'KATA', if (ctx.meta.iso != null) '${ctx.meta.iso}'].join(' ');

    return [
      ComposeSurface(ColoredBox(color: roll.ground)),
      ComposeGrainSheet(GrainSpec.measured(clumpPx: clump, amount: amount, seed: roll.seed)),
      // the film base
      ComposeSurface(Padding(
        padding: EdgeInsets.only(top: strip.top, bottom: s.height - strip.bottom),
        child: const ColoredBox(color: Color(0xFF23201C)),
      )),
      ComposeSurface(CustomPaint(painter: SprocketPainter(strip, sprocketBand, roll))),
      ComposePhotoWindow(rect: photoRect),
      // edge print: the stock is the recipe
      ComposeTextSlot(
        id: 'stock',
        region: Rect.fromLTRB(s.width * 0.06, strip.top + sprocketBand * 0.08, s.width * 0.62, strip.top + sprocketBand * 0.92),
        style: roll.voice.dataStyle(sprocketBand * 0.52, const Color(0xFFDCE6C8)),
        invitation: 'KATA',
        prefill: stockLine.toUpperCase(),
        align: Alignment.centerLeft,
        maxChars: 30,
        fitRegion: true,
      ),
      // frame numbers under the sprockets
      ComposeTextSlot(
        id: 'framenumber',
        region: Rect.fromLTRB(s.width * 0.06, strip.bottom - sprocketBand * 0.92, s.width * 0.40, strip.bottom - sprocketBand * 0.08),
        style: roll.voice.dataStyle(sprocketBand * 0.46, const Color(0xFFDCE6C8)),
        invitation: '12 →12A',
        prefill: '${(roll.seed % 36) + 1} →${(roll.seed % 36) + 1}A',
        align: Alignment.centerLeft,
        maxChars: 12,
        fitRegion: true,
      ),
      ComposeSurface(CustomPaint(painter: SpecklePainter(roll.treatment, roll.seed))),
      ComposeGrainSheet(GrainSpec.measured(clumpPx: clump, amount: amount * 0.33, seed: roll.seed), overInk: true),
    ];
  }
}

/// Rounded-rect perforations, 2 × 2.8 mm at 4.75 mm pitch, top and bottom.
class SprocketPainter extends CustomPainter {
  SprocketPainter(this.strip, this.band, this.roll);
  final Rect strip;
  final double band;
  final Roll roll;

  @override
  void paint(Canvas c, Size s) {
    // 4.75 mm pitch over a 35 mm width → the strip holds ~7.4 sprockets per frame width
    final pitch = strip.width / 12;
    final w = pitch * 0.42, h = band * 0.46;
    final p = Paint()..color = const Color(0xFF0C0D0F);
    for (var i = 0; i < 12; i++) {
      final x = pitch * (i + 0.5);
      for (final y in [strip.top + band * 0.5, strip.bottom - band * 0.5]) {
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: w, height: h), Radius.circular(math.min(w, h) * 0.28)),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(SprocketPainter o) => o.strip != strip || o.roll.seed != roll.seed;
}
```

- [ ] **Step 4: Register it**

In `frame.dart`: `const List<WakuObject> kObjects = [StampObject(), NegativeStripObject()];` with the import added.

- [ ] **Step 5: Run the tests**

Run: `cd app && fvm flutter analyze && fvm flutter test`
Expected: PASS — the fuzz test now covers two objects.

- [ ] **Step 6: Commit**

```bash
cd /home/parth/WebstormProjects/fuji
git add app/lib/features/waku/frames/negative_strip.dart app/lib/features/waku/frames/frame.dart app/test/features/frames_test.dart
git commit -m "waku: the negative strip, with the recipe as the stock

Rounded-rect sprockets at 4.75mm pitch — round holes are what gives a fake
away — the edge print above them, and frame numbers with their arrows below.
The edge print carries the kata's name where the film stock would be, which
is the neatest place in the whole set for the recipe to ride."
```

---

### Task 9: The archive label card, and Code 39

**Files:**
- Create: `app/lib/features/waku/frames/barcode.dart`
- Create: `app/lib/features/waku/frames/label_card.dart`
- Modify: `app/lib/features/waku/frames/frame.dart` (register)
- Create: `app/test/features/barcode_test.dart`

**Interfaces:**
- Consumes: `frame.dart`, `roll.dart`, `layers.dart`.
- Produces: `List<bool> code39Bars(String value)`; `class BarcodePainter extends CustomPainter`; `class LabelCardObject extends WakuObject` with `id == 'label'`.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/barcode_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/features/waku/frames/barcode.dart';

void main() {
  test('Code 39 brackets the value with its start and stop character', () {
    final bars = code39Bars('A');
    // '*' start (9 modules + gap) + 'A' + '*' stop; every character is 9 bars
    expect(bars.length, greaterThan(27));
    expect(code39Bars('A'), code39Bars('a'), reason: 'Code 39 is upper-case only');
  });

  test('different values give different bars', () {
    expect(code39Bars('KATA1'), isNot(code39Bars('KATA2')));
  });

  test('unsupported characters are dropped rather than throwing mid-export', () {
    expect(() => code39Bars('KATA-64!'), returnsNormally);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd app && fvm flutter test test/features/barcode_test.dart`
Expected: FAIL — package not resolved.

- [ ] **Step 3: Implement the barcode**

Create `app/lib/features/waku/frames/barcode.dart`:

```dart
import 'package:flutter/material.dart';

/// Code 39, the barcode a museum accession number actually carries. Each
/// character is nine modules — five bars, four spaces, three of them wide.
/// Recovered from the label card that shipped in commit 16be887.
const _code39 = <String, String>{
  '0': 'nnnwwnwnn', '1': 'wnnwnnnnw', '2': 'nnwwnnnnw', '3': 'wnwwnnnnn', '4': 'nnnwwnnnw',
  '5': 'wnnwwnnnn', '6': 'nnwwwnnnn', '7': 'nnnwnnwnw', '8': 'wnnwnnwnn', '9': 'nnwwnnwnn',
  'A': 'wnnnnwnnw', 'B': 'nnwnnwnnw', 'C': 'wnwnnwnnn', 'D': 'nnnnwwnnw', 'E': 'wnnnwwnnn',
  'F': 'nnwnwwnnn', 'G': 'nnnnnwwnw', 'H': 'wnnnnwwnn', 'I': 'nnwnnwwnn', 'J': 'nnnnwwwnn',
  'K': 'wnnnnnnww', 'L': 'nnwnnnnww', 'M': 'wnwnnnnwn', 'N': 'nnnnwnnww', 'O': 'wnnnwnnwn',
  'P': 'nnwnwnnwn', 'Q': 'nnnnnnwww', 'R': 'wnnnnnwwn', 'S': 'nnwnnnwwn', 'T': 'nnnnwnwwn',
  'U': 'wwnnnnnnw', 'V': 'nwwnnnnnw', 'W': 'wwwnnnnnn', 'X': 'nwnnwnnnw', 'Y': 'wwnnwnnnn',
  'Z': 'nwwnwnnnn', '-': 'nwnnnnwnw', '.': 'wwnnnnwnn', ' ': 'nwwnnnwnn', '*': 'nwnnwnwnn',
};

/// The bar pattern for [value]: true = ink, false = paper, one entry per module.
/// Unsupported characters are dropped — a barcode with a gap beats an export
/// that throws.
List<bool> code39Bars(String value) {
  final chars = ['*', ...value.toUpperCase().split('').where(_code39.containsKey), '*'];
  final out = <bool>[];
  for (var ci = 0; ci < chars.length; ci++) {
    final pattern = _code39[chars[ci]]!;
    for (var i = 0; i < pattern.length; i++) {
      final wide = pattern[i] == 'w';
      final ink = i.isEven;
      for (var k = 0; k < (wide ? 3 : 1); k++) {
        out.add(ink);
      }
    }
    if (ci < chars.length - 1) out.add(false); // inter-character gap
  }
  return out;
}

class BarcodePainter extends CustomPainter {
  BarcodePainter(this.value, this.color);
  final String value;
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final bars = code39Bars(value);
    if (bars.isEmpty) return;
    final w = s.width / bars.length;
    final p = Paint()..color = color;
    for (var i = 0; i < bars.length; i++) {
      if (bars[i]) c.drawRect(Rect.fromLTWH(i * w, 0, w + 0.3, s.height), p);
    }
  }

  @override
  bool shouldRepaint(BarcodePainter o) => o.value != value || o.color != color;
}
```

- [ ] **Step 4: Run the barcode test**

Run: `cd app && fvm flutter test test/features/barcode_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Implement the label card**

Create `app/lib/features/waku/frames/label_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/compose/grain.dart';
import '../../../core/compose/layers.dart';
import '../../../core/compose/roll.dart';
import '../../../core/compose/treatment.dart';
import '../../../core/compose/voice.dart';
import 'barcode.dart';
import 'frame.dart';

/// A print mounted on board beside a museum tombstone card: maker, italic
/// title, date, medium — which here is the camera and the recipe — and an
/// accession number under a Code 39 barcode. The most authenticity per unit of
/// effort on the reference board, and the frame that permits the least wear.
class LabelCardObject extends WakuObject {
  const LabelCardObject();

  @override
  String get id => 'label';

  @override
  String get label => 'Label';

  @override
  Allowances get allowances => const Allowances(
        voices: {VoiceId.deco, VoiceId.bureau},
        inkFamily: 'archive',
        // a gallery keeps its walls clean
        treatment: TreatmentBounds(slip: 0.003, bleed: 0.3, pressure: 0.08, speckles: 8, wear: 0),
        grounds: [Color(0xFFEDE8DC), Color(0xFFE6E1D3), Color(0xFFF1EDE3)],
      );

  @override
  List<ComposeLayer> build(ObjectContext ctx) {
    final s = ctx.size;
    final roll = ctx.roll;
    final m = s.width * 0.085;
    final photoRect = Rect.fromLTRB(m, s.height * 0.10, s.width - m, s.height * 0.10 + (s.width - 2 * m) * 0.72);
    final cardTop = photoRect.bottom + s.height * 0.045;
    final cardW = (s.width - 2 * m) * 0.62;
    final card = Rect.fromLTWH(m, cardTop, cardW, s.height * 0.20);
    final (clump, amount) = ctx.grain.onSheet(photoRect.width);
    final accession = 'KATA ${(roll.seed % 900 + 100)}.${ctx.meta.dateTime?.year ?? 2026}';
    final medium = [ctx.meta.model, ctx.kataName ?? ctx.meta.filmMode].whereType<String>().join(' · ');

    return [
      ComposeSurface(ColoredBox(color: roll.ground)),
      ComposeGrainSheet(GrainSpec.measured(clumpPx: clump, amount: amount, seed: roll.seed)),
      ComposeSurface(CustomPaint(painter: PressurePainter(roll.treatment, roll.seed))),
      ComposePhotoWindow(
        rect: photoRect,
        shadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      // the tombstone card
      ComposeSurface(Padding(
        padding: EdgeInsets.fromLTRB(card.left, card.top, s.width - card.right, s.height - card.bottom),
        child: DecoratedBox(decoration: BoxDecoration(color: roll.ink.withValues(alpha: 0.06), border: Border.all(color: roll.ink.withValues(alpha: 0.25), width: 0.7))),
      )),
      ComposeTextSlot(
        id: 'maker',
        region: Rect.fromLTWH(card.left + card.width * 0.06, card.top + card.height * 0.10, card.width * 0.88, card.height * 0.22),
        style: roll.voice.textStyle(card.width * 0.075, roll.ink, weight: FontWeight.w600, tracking: 0.06),
        invitation: 'YOUR NAME',
        align: Alignment.centerLeft,
        maxChars: 28,
        fitRegion: true,
      ),
      ComposeTextSlot(
        id: 'title',
        region: Rect.fromLTWH(card.left + card.width * 0.06, card.top + card.height * 0.33, card.width * 0.88, card.height * 0.26),
        style: roll.voice.displayStyle(card.width * 0.10, roll.ink).copyWith(fontStyle: FontStyle.italic),
        invitation: 'Untitled',
        uppercase: false,
        align: Alignment.centerLeft,
        maxChars: 34,
        fitRegion: true,
      ),
      ComposeTextSlot(
        id: 'medium',
        region: Rect.fromLTWH(card.left + card.width * 0.06, card.top + card.height * 0.60, card.width * 0.88, card.height * 0.18),
        style: roll.voice.dataStyle(card.width * 0.055, roll.ink.withValues(alpha: 0.8)),
        invitation: 'camera · film',
        prefill: medium.isEmpty ? null : medium,
        uppercase: false,
        align: Alignment.centerLeft,
        maxChars: 44,
        fitRegion: true,
      ),
      // accession number and its barcode
      ComposeSurface(Padding(
        padding: EdgeInsets.fromLTRB(card.left + card.width * 0.06, card.bottom - card.height * 0.20, s.width - (card.left + card.width * 0.6), s.height - card.bottom + card.height * 0.06),
        child: CustomPaint(painter: BarcodePainter(accession, roll.ink.withValues(alpha: 0.85))),
      )),
      ComposeTextSlot(
        id: 'accession',
        region: Rect.fromLTWH(card.left + card.width * 0.60, card.bottom - card.height * 0.22, card.width * 0.34, card.height * 0.16),
        style: roll.voice.dataStyle(card.width * 0.048, roll.ink.withValues(alpha: 0.75)),
        invitation: 'KATA 000',
        prefill: accession,
        align: Alignment.centerRight,
        maxChars: 18,
        fitRegion: true,
      ),
      ComposeSurface(CustomPaint(painter: SpecklePainter(roll.treatment, roll.seed))),
      ComposeGrainSheet(GrainSpec.measured(clumpPx: clump, amount: amount * 0.33, seed: roll.seed), overInk: true),
    ];
  }
}
```

- [ ] **Step 6: Register it and run everything**

In `frame.dart`: `const List<WakuObject> kObjects = [StampObject(), NegativeStripObject(), LabelCardObject()];` with the import.

Run: `cd app && fvm flutter analyze && fvm flutter test`
Expected: analyze clean; all pass, with the fuzz test now covering three objects × 4 ratios × 25 seeds.

- [ ] **Step 7: Commit**

```bash
cd /home/parth/WebstormProjects/fuji
git add app/lib/features/waku/frames/ app/test/features/barcode_test.dart app/test/features/frames_test.dart
git commit -m "waku: the archive label card, and Code 39 back from history

A print on board beside a tombstone card: maker, italic title, medium — the
camera and the recipe — and an accession number over a real Code 39 barcode,
recovered from the label card that commit 16be887 shipped before the poster
replaced it. It's the frame that permits the least wear: a gallery keeps its
walls clean."
```

---

### Task 10: The recipe rides along

**Files:**
- Modify: `app/lib/features/waku/waku_screen.dart` (attach a kata)
- Modify: `app/lib/features/waku/frames/stamp.dart`, `negative_strip.dart`, `label_card.dart` (code furniture)
- Modify: `app/test/features/waku_test.dart`

**Interfaces:**
- Consumes: `recipe_repository.dart` (`recipeRepositoryProvider`, `Recipe`), `packages/ofr` (`KataCode.encode`), `frame.dart` (`ObjectContext.kataName`, `.kataCode`).
- Produces: no new API.

- [ ] **Step 1: Write the failing test**

Add to `app/test/features/waku_test.dart`:

```dart
  testWidgets('a kata can be attached, and its name reaches the object', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF667788))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    await t.tap(find.text('ATTACH A KATA'));
    await t.pumpAndSettle();
    await t.tap(find.text('Kodachrome 64').first);
    await t.pumpAndSettle();
    expect(t.state<WakuScreenState>(find.byType(WakuScreen)).kataName, 'Kodachrome 64');
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd app && fvm flutter test test/features/waku_test.dart --plain-name "a kata can be attached"`
Expected: FAIL — `ATTACH A KATA` not found.

- [ ] **Step 3: Add attachment to the screen**

In `waku_screen.dart`:

```dart
  Recipe? _kata;
  String? get kataName => _kata?.name;

  Future<void> _attachKata() async {
    final repo = ref.read(recipeRepositoryProvider);
    final picked = await showKataSheet<Recipe>(
      context,
      builder: (c) => KataSheet(
        eyebrow: 'Waku',
        title: 'Attach a kata',
        children: [
          for (final r in repo.all.take(40))
            KataListRow(title: r.name, value: r.ofr.filmSimulation, onTap: () => Navigator.of(c).pop(r)),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _kata = picked);
  }
```

and in `_controls`, above the Shuffle button:

```dart
        KataPillButton(
          label: _kata == null ? 'Attach a kata' : _kata!.name,
          kind: KataButtonKind.secondary,
          display: true,
          height: 38,
          onPressed: _attachKata,
        ),
```

Pass it through in `_layers`:

```dart
        kataName: _kata?.name,
        kataCode: _kata == null ? null : KataCode.encode(_kata!.ofr),
```

Where the photo's EXIF film simulation matches a kata already in the library, preselect it after import:

```dart
    final sim = meta.filmMode?.toUpperCase();
    final match = sim == null
        ? null
        : ref.read(recipeRepositoryProvider).all.where((r) => r.ofr.filmSimulation.toUpperCase() == sim).firstOrNull;
```

and set `_kata = match;` inside the same `setState` as the rest of the import.

- [ ] **Step 4: Put the code where the object would carry one**

In `stamp.dart`, after the postmark layer, add the Kata Code as the cancellation's companion — a small square in the stamp's lower-right corner:

```dart
      if (ctx.kataCode != null)
        ComposeSurface(Padding(
          padding: EdgeInsets.fromLTRB(face.right - stampW * 0.20, stamp.bottom - stampH * 0.20, s.width - face.right, s.height - stamp.bottom + stampH * 0.04),
          child: KataCodeMark(payload: ctx.kataCode!, color: roll.ink),
        )),
```

In `negative_strip.dart`, the DX latent code sits below the sprockets opposite the frame numbers:

```dart
      if (ctx.kataCode != null)
        ComposeSurface(Padding(
          padding: EdgeInsets.fromLTRB(s.width * 0.62, strip.bottom - sprocketBand * 0.92, s.width * 0.06, s.height - strip.bottom + sprocketBand * 0.08),
          child: LayoutBuilder(builder: (c, b) => KataCodeQr(payload: ctx.kataCode!, size: b.biggest.shortestSide, inverted: true)),
        )),
```

In `label_card.dart`, it replaces the Code 39 when a kata is attached — a museum label would carry one code, not two:

```dart
        child: ctx.kataCode == null
            ? CustomPaint(painter: BarcodePainter(accession, roll.ink.withValues(alpha: 0.85)))
            : LayoutBuilder(builder: (c, b) => KataCodeQr(payload: ctx.kataCode!, size: b.biggest.shortestSide)),
```

`KataCodeQr` already exists at `app/lib/features/share/kata_code_qr.dart` with the
signature `KataCodeQr({required String payload, required double size, bool inverted = false})`.
Import it (`import '../../share/kata_code_qr.dart';`) rather than inventing a new
widget; it takes a size rather than a colour, hence the `LayoutBuilder` at each
call site, and `inverted` is what makes it read on the negative's dark base.

- [ ] **Step 5: Run the tests**

Run: `cd app && fvm flutter analyze && fvm flutter test`
Expected: analyze clean; all pass.

- [ ] **Step 6: Commit**

```bash
cd /home/parth/WebstormProjects/fuji
git add -A
git commit -m "waku: the recipe rides the object

Attach a kata — preselected when the photo's film simulation already matches
one in the library — and it becomes the object's content: the stamp's country
line, the negative's stock, the label's medium. Its Kata Code then goes where
that object would carry a code anyway: beside the cancellation, in the DX
latent strip, or in place of the accession barcode. Scanning a posted picture
puts the recipe in someone's camera."
```

---

### Task 11: Ship it

**Files:**
- Modify: `docs/design/waku-frames.md` (mark the old shortlist as reference-only)
- Modify: `docs/design/waku-direction.md` (tick off what landed)

- [ ] **Step 1: Run the whole suite and the analyzer across every package**

```bash
cd /home/parth/WebstormProjects/fuji/app && fvm flutter analyze && fvm flutter test
cd ../packages/kata_ui && fvm flutter test
cd ../fuji_ptp && fvm flutter test
cd ../ofr && fvm dart test
```
Expected: all green.

- [ ] **Step 2: Look at the output**

Build and run the dev grid against a real photograph, for each of the three objects, and look at nine rolls of each:

```bash
cd /home/parth/WebstormProjects/fuji/app && fvm flutter run -d linux --release
```
Navigate to Waku, pick a photo, and shuffle at least ten times per object. What you are checking, which no test can: does each object read as that thing; do the voices differ audibly; does the ink stay in family; is the wear plausible rather than decorative.

- [ ] **Step 3: Update the docs**

In `docs/design/waku-frames.md`, add at the top:

```markdown
> **Status (2026-08-26):** the frames described here — polaroid, poster, words —
> were retired. This file survives as the reference inventory that fed
> `waku-spec.md`; the built objects are stamp, negative strip and label card.
```

In `docs/design/waku-direction.md`, mark item 2 (photo slots) as still open and note that objects landed.

- [ ] **Step 4: Commit**

```bash
cd /home/parth/WebstormProjects/fuji
git add docs/design/
git commit -m "docs: the frame set is objects now

waku-frames.md keeps its shortlist as the reference inventory it always was;
the built set is stamp, negative strip and label card, each an authored
object with a rolled surface."
```

---

## Self-Review

**Spec coverage.** §3 model → Tasks 4, 5. §4.1 voice → Task 1. §4.2 ink → Task 2. §4.3 treatment → Task 3 (grain reuses the existing measurement, wired per object in Tasks 6, 8, 9). §5 interaction → Task 7. §6 Kata tie → Task 10. §7 scope, three objects → Tasks 6, 8, 9. §8 what goes → Task 7 (deletes `waku_frames.dart`), Task 6 (deletes the spike). §9 testing → determinism and allowances in Task 4, contrast in Task 2, bounds in Task 3, pins in Tasks 4 and 7, ratio × seed fuzz in Task 5, bias statistics in Task 1, eyeball harness in Task 6.

**Gap found and closed:** the spec's §9 asks for a *statistical* bias test; Task 1's second test asserts the relative weighting rather than any single draw, which is the same guarantee without flakiness.

**Placeholders:** none — every step carries the code or the command it needs.

**Type consistency:** `Roll.draw` is called with the same named parameters in Tasks 4, 5, 6 and 7. `ObjectContext` is constructed identically in Tasks 5, 6, 8 and 9. `Allowances` field names (`voices`, `inkFamily`, `treatment`, `grounds`) match between Task 4's definition and every object's use. `GrainSpec.measured({clumpPx, amount, seed})` matches the existing signature in `core/compose/grain.dart`.
