# Waku/compose film grain — research synthesis & design

Research: three parallel tracks (academic models · production implementations ·
GPU shader techniques), 2026-08-24. Full agent reports in session history;
extracted paper texts were reviewed for the math below.

## What the literature agrees on

1. **Ground truth is the Boolean model** (Newson–Delon–Galerne, IPOL/CGF 2017):
   film is a union of opaque disks — Poisson-distributed centers, log-normal
   radii — where exposure sets density via `λ(u) = k · log(1/(1−u))`, and the
   observed image is that binary field through a Gaussian filter (σ ≈ 0.8
   output px). Everything real about grain falls out: variance peaks at
   mid-gray and vanishes at both extremes, clumping emerges from disk overlap,
   grain fades under reduction (Selwyn's law), dark-area behavior differs from
   light. Zhang et al. (SIGGRAPH 2023) prove a Gaussian field with the Boolean
   statistics is visually identical when grains are sub-pixel — the normal case.
2. **Production consensus** (AV1 normative synthesis, Dehancer, Unreal/Unity):
   additive grain scaled by a piecewise-linear intensity→strength curve
   (`Y' = Y + f(Y)·G`), spatial correlation from a small precomputed
   band-passed template (AR-filtered noise) tiled with random offsets. AV1's
   path is deliberately royalty-free; the H.264-era frequency-domain method is
   a Thomson patent family — avoid.
3. **Cheap tells** (what makes grain read fake): white-noise spectrum (needs
   band-pass "clump" energy), screen-space instead of film-space coordinates,
   single particle size ("sandpaper"), flat tonal response, hard 1-px edges
   (missing the 0.8 px optics blur).

## Our constraint

Flutter Impeller `ImageFilter.shader`: single pass, **only the input sampler**
— no second texture can ever be bound. So AV1-style baked templates and blue-
noise textures are out; correlation must be built procedurally per fragment.
The Boolean particle model needs *no* texture — its correlation comes from the
disks themselves — which makes it, unusually, the best fit for our constraint.
Cost is fine because compose surfaces render once per state change and once at
export, not per animation frame.

## Design: one shader, two tiers

`shaders/grain.frag`, tier selected per **frame curation** (never by users).

- **Tier 0 — paper tooth** (frame stock: polaroid chin, mat board, card):
  film-space value noise band-passed by a 2-tap high-pass
  (`n(p) − n(p + ½cell)`), amplitude shaped by the mid-gray parabola
  `mix(1−(2L−1)², 1, C)`, applied additively. ~50 ALU. Subtle, matte, correct
  for printed paper.
- **Tier 1 — film grain** (photo-bearing surfaces; future share-card looks):
  reduced Newson pixel-wise model. Per fragment: λ from the local luminance
  (hoisted once), N=12 shared Gaussian offsets (precomputed on the Dart side,
  passed as uniforms, scaled σ=0.8 px), each offset a Worley-style 3×3 cell
  gather — per cell: hash-seeded PRNG, inverse-transform Poisson (≤4 terms),
  uniform center, log-normal radius clamped to 2δ, squared-distance test,
  early exit. Coverage → `grainL = 1 − coverage`; apply as
  `rgb · mix(1, grainL/max(L,ε), amount)` — hue-preserving, physically toned.
  N=12 ⇒ ~14% MC error, which — offsets being shared across fragments — reads
  as extra fine grain, not error.
- Grain size stays in **physical pixels** (µ_r · devicePixelRatio) so exports
  render finer, denser grain — the resolution-true behavior scanned plates
  can't do.
- Loops use compile-time bounds with breaks (Impeller Metal/GLES safety).

## Curation surface (internal API, per frame)

`GrainSpec{tier, strength, size, seed}` on `ComposeSurface` (and later on
photo-look features). Users never see grain controls. Fuji vocabulary retained:
strength Weak/Strong, size Small/Large map to (amount, µ_r). A future tie-in:
a recipe's ISO can drive amount via the photon-noise law (shot noise ∝ √e⁻),
matching aomenc's photon-noise tables.

## Later (researched, deliberately deferred)

- Per-channel color-neg grain (blue layer coarsest: µ_r blue > green ≥ red),
  dye-cloud softness (larger blur for color looks).
- AV1-style AR template if a second sampler ever becomes possible (or via
  pre-compositing the grain field on the Dart side as an image layer).
- Piecewise-linear f(Y) authored per stock, fitted from Boolean statistics.
- Neural approaches (InterDigital, CGF 2025): not shader-tractable; ignore.

## Verification

Shader compiles at build (impellerc); runtime smoke on macOS/Android; visual
sign-off by Parth at preview and export scales (grain must tighten, not
enlarge, at export). Unit tests cover the Dart-side offset generation and
spec plumbing; shader visuals are judged by eye — that's what curation is.
