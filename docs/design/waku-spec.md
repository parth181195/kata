# Waku — design spec

**Date:** 2026-08-26
**Status:** approved in brainstorm, not yet planned
**Supersedes:** the frame set described in `waku-frames.md` (polaroid, poster, words)

## 1. What it is

Waku turns a photograph into a **printed object that carries the recipe that made
it**. Not a template gallery: you give it a shot, it hands you a finished object,
and you shuffle until one is yours.

## 2. Why this is a rewrite

Three complaints against what shipped, all confirmed:

- **They're layouts, not objects.** A stamp has perforations, a negative strip has
  sprockets, a ticket has a punch hole. The frames we built have grids and type.
  Recognisable-across-a-room identity is what's missing.
- **Too clean, one voice.** No misregistration, no bleed, no wear, no dust — and a
  single grotesque doing every job, so every frame speaks identically.
- **Nothing needs Kata.** Any photo app could ship it.

The interaction was wrong too: a gallery asks you to choose an object before you
know what it will look like with your photo in it.

## 3. The model

A frame is three things, and only one of them varies.

**Identity — authored, never rolled.** The object itself: its silhouette, its
furniture, the marks that make it that thing. Perforation edge and postmark for a
stamp; sprockets, edge print and frame numbers for a negative strip; tombstone
card and accession number for an archive label. Hand-built per frame.

**Slots — authored.** Where the shot's content lands: the photograph, the credit
block, the title where the object has one, the Kata Code. Where a stamp's
denomination sits is a design decision, not a variable.

**Allowances — what the roll may touch.** Declared per frame: which voices suit
it, which inks are in character, which treatments are plausible and how far each
may go. A museum label permits two sober voices and no wear; a stamp permits
cancellation ink and a torn perforation but no coffee ring. **The frame curates
its own variety.**

## 4. The three rolled axes

One integer seeds all three. A shuffle is a new seed; any output is reproducible
from (photo, frame, seed).

### 4.1 Voice

A pairing of three roles — **display** (the numeral, the big mark), **text** (the
country line, the caption) and **data** (dates, codes) — drawn from a registry of
curated pairings. Each frame lists the voices it allows.

The shot biases which is drawn:

| Signal | Pull |
|---|---|
| Monochrome film sim (Acros, Monochrome) | high-contrast serif / didone voices |
| Classic Neg, Nostalgic Neg, Eterna | warm mid-century grotesque and slab voices |
| Classic Chrome, Provia, Reala | neutral bureau voices |
| Velvia, high saturation | condensed poster voices |
| ISO ≥ 3200 | rougher, heavier display faces |

Bias means weighting, not forcing: every allowed voice keeps a non-zero chance,
so shuffling still surprises.

**Fonts are bundled, not fetched.** Kata works offline; a frame that needs the
network to render is a frame that fails on a plane. The v1 voice set ships as
assets, with `google_fonts` runtime fetching disabled.

### 4.2 Ink

Each frame declares an ink family in character for the object (a postmark is
red-black, an archive label maroon-black). The photo biases the choice within
that family, and a **contrast floor against the ground is enforced** — an ink that
fails it is darkened until it passes.

### 4.3 Treatment

The imperfection, drawn per output and bounded per frame:

- **registration slip** — a printed layer offset and slightly rotated
- **ink bleed** — edge spread on printed marks
- **uneven pressure** — low-frequency density variation across the sheet
- **speckle** — dust, hairs, specks from a dirty shop
- **wear** — a torn perforation, a bent corner, an abraded edge
- **grain** — the measured tooth from `waku_grain_measure`, already built

## 5. Interaction

1. **Choose a photo.** Unchanged (JPEG/PNG/WebP/RAW, EXIF, palette, grain measured
   on import).
2. **A finished object appears immediately** — frame chosen, all three axes rolled,
   the shot's data in place. No title is demanded; frames that take one show an
   invitation only in edit mode.
3. **Shuffle** is the primary control: new seed, possibly a different object.
4. **Pins** make it a tool rather than a slot machine. Each axis locks
   independently — *this object, reshuffle the rest*; *keep the voice*; *keep the
   ink, try another treatment*.
5. **Frames drawer** (secondary) pins a specific object.
6. **Edit mode** (secondary) reveals slots for typing and placement, with the
   controls already built: size and tilt sliders, ink swatches, drag-to-place.
7. **Export** through the existing path, at the chosen ratio.

## 6. What makes it Kata's

**The recipe is the object's content**, not a badge: film simulation as the
stamp's country line, settings as the credit block, the kata's name as the title.

**The Kata Code is furniture**: it goes where that object would carry a code
anyway — the cancellation on a stamp, the barcode on a ticket, the DX latent code
on a negative strip. Never a QR pasted into a corner.

**Attaching a kata**: if the photo's EXIF film simulation matches a kata in the
library, Waku offers it; otherwise the user picks one. The frame then carries it,
and scanning a posted picture puts the recipe in someone's camera.

## 7. Scope

**v1 ships three objects**, all single-photo, all with strong identity:

1. **Postage stamp** — perforated edge, denomination, country line, arced postmark
   that laps onto the mount. Proven in the spike.
2. **35mm negative strip** — rounded-rect sprockets at 4.75 mm pitch, edge print
   carrying the recipe name as the stock, frame numbers with arrows, DX latent
   barcode.
3. **Archive label card** — photo mounted on stock beside a tombstone card:
   artist, italic title, date, medium, accession number and barcode. (A Code 39
   generator for this exists in git history at commit `16be887`.)

**Out of scope for v1**, in rough priority order for later: multi-photo objects
(grids, contact sheets, diptychs), frames as fetched documents rather than Dart,
motion export, halftone/riso surface, community-authored frames.

## 8. What is kept, and what goes

**Kept:** the compose engine (`ComposeLayer`, slots, `ComposeCanvasView`,
fit-to-region), the ratio solver (`sheet_layout.dart`), grain measurement and its
two-pass application, the export path, photo import with RAW/EXIF/palette, and
the editing controls (size, tilt, ink, drag).

**Removed:** the three current frames — polaroid, poster and words — and the
gallery-first screen. They are layouts; retrofitting them would carry that
compromise into the new set. `waku-frames.md`'s shortlist survives as the
reference inventory, not as built code.

## 9. Testing

Taste can't be asserted; the rules can.

- **Determinism** — the same (photo, frame, seed) yields an identical roll.
- **Allowances** — fuzz several hundred seeds per frame; every rolled voice, ink
  and treatment must be one the frame declared.
- **Legibility** — across those rolls, ink-on-ground contrast never drops below
  the floor.
- **Pins** — a pinned axis holds across repeated shuffles while the others move.
- **Layout** — fuzz ratios × seeds; no slot escapes the sheet (extends the
  existing `sheet_layout_test`).
- **Bias** — a monochrome shot draws serif voices more often than a Velvia shot
  does, over many seeds. Statistical, not per-roll.
- **Eyeball harness** — a dev-only screen rendering a grid of rolls, kept in the
  repo rather than thrown away. Humans judge the taste.

## 10. Decisions already made

- Frames are Dart classes in v1, not documents. Documents come after the schema
  has proved itself on three objects.
- Fonts bundled, runtime fetching off.
- Shuffle is one integer; pins are per-axis.
- The photo's own grain sets the sheet's tooth (already built and measured).
- The poster's ratio-responsive grid work survives as the solver, even though the
  poster itself does not.
