# Kata design (from the design tool)

Source project: (design-tool export)
Snapshot: `Kata.dc.html` (2026-08-19). `support.js` / `image-slot.js` are the canvas runtime.

## Tokens
| Token | Value | Use |
|---|---|---|
| bg / fg (dark) | `#000000` / `#FFFFFF` | page, primary pill |
| bg / fg (light) | `#FFFFFF` / `#000000` | |
| grey900 | `#0A0A0A`–`#1A1A1A` | code block bg, hairline dividers (dark) |
| grey700 | `#2E2E2E` | card outlines, chips, dotted rules (dark); body text (light) |
| grey500 | `#8A8A8A` | labels, secondary text, inactive icons |
| grey300 | `#D9D9D9` | values/secondary text (dark); outlines, hairlines (light) |
| red | `#D71921` | ONLY: overwrite warning, skipped-settings card, validation issues, "Overwrite" outline button |
| Display font | **Doto** 800/900, uppercase, `letter-spacing .03–.06em` | wordmark, titles, recipe names, slot labels, primary button labels, big numbers |
| Body font | **Inter** 400/500/600 | body, descriptions, secondary buttons |
| Mono font | **JetBrains Mono** 400/500 | all values, chips (uppercase, `letter-spacing .14–.16em` for labels), status pills |
| Radii | cards 16–18, sheets 26 top, chips/pills full, slot badge 8–9 | |
| Hairline | 1px solid grey700 (dark) / grey300 (light); dotted rules `repeating-linear-gradient(to right, grey 0 2px, transparent 2px 5px)` | |
| Bottom nav | 64px, 4 icon-only tabs (Library ▭, Camera ◯, Mine ⊔, Profile ◠), 4px dot under active | |

## Components (kit, 1g)
- **SwatchBars**: 5 vertical bars, heights/greys derived from (highlight, shadow, color, sharpness, clarity); film-sim abbreviation in Doto below (CC, ACR, VEL, PNS, NN, ETR…).
- **StatusPill**: CONNECTED (white fill, black dot) · DISCONNECTED (outline, hollow dot) · OFFLINE (outline, grey dot) · NO CAMERA · `X-S20 · C1–C4` variant on detail.
- **VerifiedBadge**: 15–17px white circle with ✓.
- **SpecCell**: label (Inter 8.5px, .16em, grey500) over value (JetBrains Mono 13–15px; film sim uses Doto 14px). Optional **Ruler** under tone cells: ticks `repeating-linear-gradient(to right, grey700 0 1px, transparent 1px 7px)`, 1.5px white marker at value position. Editing variant: 1.5px white outline, bigger ruler, min/0/max labels.
- **SlotCard**: filled (outline grey700, C-badge outlined), on-dial (1.5px white outline, C-badge filled white, "ON DIAL"/"DIAL" chip), empty (dashed outline, grey text "EMPTY / FACTORY DEFAULT · TAP TO FILL").
- **Buttons**: Primary pill (white, Doto uppercase label, 56–58px), Secondary (outline grey700, Inter 600), Tonal (grey900 fill), Overwrite (red outline/text), Icon circle 44–50px, Big round Connect 108px (74 in kit).
- **Sheet**: 26px top radius, 44×4 grabber, eyebrow label (mono .16em grey500) + Doto title.
- **Toast**: outline card, white dot, text, mono UNDO.
- **IssueRow**: left Inter text, right mono reason, dotted separators, inside red-outline card.
- **Checklist step**: numbered 26px circle (Doto), title Inter 600 13px, sub grey500.

## Screens
1a Sign-in · 1b Library (full-bleed first card, compact cards, filter chips VERIFIED/X-TRANS V/B&W/FILM SIM, sort NEWEST/POPULAR, offline banner, empty state) · 1c Detail (hero photo + name + verified + summary line + swatch; source link; sensor chips; 3 thumbs; "Q-MENU ORDER" divider; 3-col spec grid; bottom bar ♡ / WRITE TO CAMERA / ⋮; light variant with "NO CAMERA" pill + disabled write + hint card) · 1d Camera (checklist + big Connect; connected: model header, `FW · X-TRANS V · 4 SLOTS · ON DIAL: C2`, slot grid 2×2, READ ALL ↻, "C2 — WHAT'S IN THE CAMERA" panel with Save as kata / Overwrite with…) · 1e Write (choose slot + red overwrite card "Save what's in it first?"; writing screen: 6×4 dot matrix, "WRITING 18/22", progress bar, Cancel; done: ✓ circle, "WRITTEN TO C3", dial-flick card (white outline, "!" badge), skipped list (red outline), Fix WB in camera / DONE) · 1f Export (eyebrow, title, JSON block, Copy JSON / Save .ofr.json, share row) & Import (parsed grid, red "2 FIELDS NEED ATTENTION" issue list, ↻ / SAVE TO MINE).

## Beyond the Stage 1 spec (carry as data, flag as decisions)
- Sample photos per recipe (hero, 3 thumbs, card frames) → `imageUrls[]` on recipe docs; placeholders when empty.
- "EXP. COMP" spec cell → OFR `extra["x_exposure_comp"]` (not part of OFR v1).
- "ON DIAL: C2" assumes we can read the dial-selected slot — unknown on the wire; show only if discovered.
