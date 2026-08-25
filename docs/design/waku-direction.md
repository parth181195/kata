# Waku as a frame tool for the feed

The frames borrow print language, but nothing is going to a printer: these
images are made to be posted. That changes what "complete" means, and most of
the change is structural rather than cosmetic.

## 1. What the target actually imposes

- **It is seen small first.** A feed thumbnail is a few hundred pixels wide. A
  frame has to survive that: one dominant element, real contrast, type either
  large or absent. The poster's five credit columns disappear at 400 px — they
  were designed at full size, which is the wrong place to start.
- **The platform re-encodes.** Instagram delivers around 1080 px wide, JPEG,
  moderate quality. Fine grain is destroyed or turned to mush; hairlines alias.
  Texture has to be sized against the *delivered* pixels, not ours.
- **Ratios are dictated, not chosen.** 4:5 feed, 1:1, 9:16 story, 1.91:1 link
  card. A frame is not a canvas, it's a family that reflows.
- **Safe zones are real.** Stories cover the top ~14 % and bottom ~20 % with
  UI; Reels take the right rail. A title at the foot is a title nobody sees.
- **Motion outperforms stills** in the story/Reels surfaces — three seconds of
  drift and settling type, not a video editor.
- **The share is the loop.** Every export should carry its Kata Code, so a
  posted picture is also a recipe someone can pull into their camera. That is
  the thing no other frame tool can do.

## 2. The architecture that follows

**A. Ratio-responsive layout, before anything else.** Every frame hand-built at
2:3 is debt. Layers should declare anchors and constraints — "photo hangs from
the foot with a 14 % margin", "title sits above it, minimum gap 4 %", "credits
ride the top edge" — not fractions of one canvas. One frame then renders at 4:5,
1:1 and 9:16 instead of needing three. This is the difference between shipping
three frames and shipping thirty.

**B. Photo slots, plural.** Grids, contact sheets, diptychs and timestamp
sheets are half the reference board and all need 2–12 photos. The model has one
photo today; that's the single biggest missing capability.

**C. Frames as documents, not functions.** Each frame is currently a Dart
function. A complete tool needs dozens, and hand-writing each is the
bottleneck. A frame should be a declarative layer document: layers with
relative geometry, slots with capabilities, rules per ratio. Then frames ship
without an app release (fetched like recipes), the same document renders on
phone, desktop and web, and other people can author them — which is the same
open posture as OFR. The sealed `ComposeLayer` set is most of that schema
already; it needs serialising and a constraint vocabulary.

**D. Content-aware placement.** We already read palette, EXIF and film
simulation. Add orientation, a saliency pass for where the subject sits, and
ground luminance. Then the tool proposes rather than presents: dark vertical
portrait → these four frames, ink picked from the photo, title placed where it
doesn't land on a face. That is what separates a tool from a template gallery.

**E. Variants.** One tap reshuffles within the frame's own rules, seeded and
repeatable. Cheap once layout is declarative; impossible while it's hand-coded.

**F. Export as a set.** One press yields the 4:5, the 9:16 with safe zones
respected, the 1:1, optionally a carousel and a three-second MP4 — each with
the Kata Code embedded. That is the actual product for "sharing online", and
it's a packaging problem, not a rendering one.

**G. Delivery-aware texture.** Size grain against the delivered resolution,
drop it below the size where compression eats it, and keep it out of areas that
will be crushed. The measurement work already gives us the number to scale.

## 3. What not to build

Print fidelity: CMYK separations, bleed and crop marks, dpi and paper profiles.
It's where a print tool would go next and it would be entirely wasted here.

## 4. Order

1. Ratio-responsive layout (A) — everything else compounds on it.
2. Photo slots (B).
3. Export set with safe zones and the embedded Kata Code (F).
4. Frames as documents (C), once the schema has proved itself on six or so
   hand-built frames.
5. Content-aware placement and variants (D, E).
6. Motion export.

Grain, halftone and the rest of the surface work sit underneath all of this and
can proceed independently — they're already the compose engine's business
rather than any one frame's.
