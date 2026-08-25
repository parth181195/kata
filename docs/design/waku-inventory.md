# Waku frame inventory — read from 97 references

Source: `~/Downloads/fuji`, 97 images, indexed as #00–#96 (contact sheets and an
index file were generated to read them; the numbers below are that index). This
is the answer to two questions: what can the app draw on its own, and what needs
something only Parth can hand over.

## 1. The layout grammar underneath

Ignoring subject matter, the references reduce to seven structures. Frames are
cheap to add once the structure exists, so this is the more useful inventory.

1. **Big-margin sheet, photo low, statement type high.** ~10–12 % side margins,
   photo occupying the lower 40–60 %, a display line above it, small credits
   below or beside. #03, #13, #18, #66, #70, #87, #92, #95. **This is our poster
   frame** — the references validate the proportions we shipped.
2. **Side rail.** Metadata set vertically up a margin: index number, year,
   location, stock. #05, #19, #27, #40, #61, #95. Cheap addition to any frame —
   a `RotatedBox` and a slot; the words frame already does it with the year.
3. **Header strip.** A hairline row of tiny caps across the top — author ✳ year,
   or section · issue. #01, #26, #74, #92. One row, three slots.
4. **Asymmetric two-column.** Photo on one side, a block of set text on the
   other, aligned to a shared baseline. #43, #86, #88. **This is our words
   frame.** #88 (Petrichor) is startlingly close to what we shipped.
5. **Grid of cells.** 3×3 to 5×5, photos in some cells, type or blank stock in
   others, one cell often a giant numeral. #16, #26, #33, #50, #67, #83, #90.
   Needs multi-photo import — an app capability, not an asset.
6. **Full-bleed photo, type overlaid low.** #21, #48, #84, #89. Trivial.
7. **The frame as a photographed object.** A stamp on red card, a postcard on
   linen, a print on a desk. #00, #14, #31, #55, #60, #64, #77. These are
   *mockups* — the interesting part is the surface and the shadow, neither of
   which we can invent convincingly. See §3.

Two constants across almost every reference: **one accent colour** (nearly always
a hard red, occasionally mustard or riso blue) against cream/black, and **type
doing the structural work** rather than ornament. Both are already the kata
palette law.

## 2. Buildable in code, today, with what we ship

Roughly 55 of the 97 fall here. Grouped by what would have to be written:

| Frame | References | What it needs | Effort |
|---|---|---|---|
| **Postage stamp + postmark** | #00 #15 #21 #22 #55 #60 | Scalloped perforation path, denomination corner, arced circular date stamp, 5–7 wavy killer bars broken by ink noise | Medium — the perforation is a path, not an asset |
| **Film strip / edge print** | #11 #28 #63 #76 #80 | Rounded-rect sprockets at 4.75 mm pitch, edge print (`FUJI CLASSIC NEG 400`), frame numbers with arrows, DX latent barcode | Easy–medium; single-frame and multi-frame variants |
| **Photo grid / timestamp** | #16 #26 #33 #50 #67 #83 #90 | Cell grid, red mono timestamps from EXIF, one giant numeral cell | Easy, **but needs multi-photo import first** |
| **Ticket / receipt / pass** | #10 #23 #68 #82 | Dashed rules, serial, punch hole, barcode, thermal fade, torn edge | Easy |
| **Magazine cover** | #25 #45 #49 #69 #77 | Masthead, coverlines, issue block, barcode | Easy |
| **Album sleeve** | #29 #40 #56 #61 | Square canvas, spine-style rail, track-list block | Easy |
| **Museum label card** | #54 #86 #91 | Tombstone card: artist / italic title / date / medium / accession + barcode | **Already written once** — see §5 |
| **Halftone / riso** | #22 #51 #53 #59 #71 #73 #94 | Fragment shader: 1–2 spot colours, dot screen at an angle, 1–3 mm misregistration | Hard — the showpiece, and the one shader we don't have |
| Poster variants | #01 #19 #27 #35 #36 #92 #95 | Side rail, header strip, caption block under the image | Trivial, each ~an hour |
| Book-cover set | #96 | Cream stock, small caps author, painterly mark — the mark is the problem, see §3 | Medium |

Everything above uses fonts we already ship (Doto, Inter, JetBrains Mono) and
paint we can generate. **Nothing in this table needs you.**

## 3. Needs assets from you

About 20 references, and they cluster tightly — it's the same shelved sticker kit
plus two new asks.

**a. Fasteners and marks** (#07 #08 #12 #38 #39 #41 #42 #49 #65 #72 #81)
Drawn versions read as clip-art; that's why the kit is switched off. What to
shoot, flat-lit on plain white, as large as your camera will give:
- washi tape and masking tape — **4–6 pieces**, torn at both ends, different tear
  shapes, one folded over
- a paper clip, a bulldog clip, a push pin (straight down **and** at ~30°, so the
  pin can cast a real shadow), two staples
- a red hanko/seal impression on paper — 3 presses, ink density varying
- torn paper edges: tear a cream sheet and shoot **3–4 edge samples**
- grease-pencil / china-marker circles and arrows on white — the #08 gesture

I key those to alpha and they become draggable elements on any frame.

**b. Surfaces, for "the print as an object"** (#00 #14 #31 #55 #60 #64 #77)
A frame photographed lying on something is a different product from a frame
rendered flat, and it's the look half your board has. Needs: your desk, kraft
paper, linen, a coloured card — **flat even light, shot square-on**, no strong
shadow of its own. We composite the print onto it with a generated shadow.

**c. A painterly mark set** (#96, and the red gestures in #17 #59)
Only if you want the book-cover family. Brush strokes and ink blooms on white,
a dozen, single colour.

## 4. Needs a dependency, not an asset

**Handwriting** (#02 #12 #32 #52 #74 #81) is in a sixth of the board and we
cannot fake it: it must be a licensed script font, since the text is typed live
by the user. Candidates need a licence that allows embedding in an app. Your own
handwriting only works for *fixed* words baked as images — worth doing for a
signature slot, not for editable lines.

## 5. Already built, then dropped — recoverable

The **archive label card** (commit `16be887`) was superseded by the poster in
`5368cfa`, and it took a working **Code 39 barcode generator** with it. Stamps,
tickets, receipts and the label card all want that generator; it's in git
history, not lost.

## 6. What I'd build next, in order

1. **Stamp + postmark** — highest authenticity per unit of effort, entirely
   procedural, and the board's most repeated single object.
2. **Film strip / edge print** — the other object photographers recognise
   instantly, and the edge print is where a recipe name belongs.
3. **Multi-photo import → the timestamp grid** — unlocks a whole family (#90 is
   the strongest single reference on the board) and is an app capability the
   compose engine will want anyway.
4. **Poster variants** (side rail, header strip) — hours each, and they make the
   one frame we have feel like five.
5. **Halftone/riso shader** — the showpiece, after the grain work settles, since
   it's the same kind of problem.

Stickers stay off until §3a lands.
