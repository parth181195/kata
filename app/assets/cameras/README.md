# Camera line art

One SVG per body, monochrome strokes (white on transparent — the app tints to the theme), ~3:2 aspect, no text.
File name = slug from `packages/fuji_ptp/lib/src/fuji/known_bodies.dart`:

Tier A (preset write): x-s20 · x-t5 · x-h2 · x-h2s · x-t50 · x-m5 · x-e5 · x-t30-iii · x100vi · gfx100-ii · gfx100s-ii · gfx100rf
Tier B (probe at connect): x-t4 · x-s10 · x-pro3 · x100v · x-t3 · x-t30 · x-t30-ii · x-e4 · gfx100s · gfx100 · gfx50s-ii
Tier C (read-only): x-t2 · x-pro2 · x-h1 · x-t20 · x100f · x-e3 · gfx50s · gfx50r · x-t1 · x-t10 · x100t · x-e2 · x-pro1 · x-e1 · x-t200 · x-a7 · xf10

`generic.svg` is the fallback for anything without its own file. Missing files fall back to the hatched placeholder.
