# Compose film grain — research, what shipped, what's next

Grain belongs to the compose engine, not to Waku: the frames are its first
consumer, share cards are the next. This is the research behind it, what the
engine actually does today, and where the two disagree.

Sources are cited inline so the numbers can be checked. Two rounds of research:
2026-08-24 (the shipped design) and 2026-08-22 (this revision — colour, tonal
response, and the resolution question).

## 1. The physics, from the primary sources

**The Boolean model is ground truth.** Newson, Faraj, Delon & Galerne, *Realistic
Film Grain Rendering*, IPOL 2017 ([paper](https://www.lirmm.fr/~nfaraj/publications/film_grain_ipol/2017_Newson_film_grain.pdf)).
Film is a union of opaque disks: centres from a Poisson process, radii i.i.d.
log-normal (mean µ_r, variance σ_r²). Density follows the image because

    λ(y) = 1/E[πr₁²] · log(1 / (1 − ũ(⌊y⌋)))

where ũ is the pixel value normalised into [0,1). The observed image is that
binary field seen through a Gaussian kernel φ of variance σ², evaluated by Monte
Carlo with N samples — and **the same random offsets ξ_k are reused for every
pixel**, which is what makes it affordable.

Everything real about grain falls out of this: variance peaks at mid-grey and
vanishes at both extremes, clumping emerges from disk overlap without being
modelled, and the model is continuous — so it renders at any resolution.

**The crystal-stack model is the modern production one.** Aurélien Pierre,
*Stochastic photographic grain synthesis from crystallographic structure
simulation* ([paper](https://eng.aurelienpierre.com/2023/07/stochastic-photographic-grain-synthesis-from-crystallographic-structure-simulation/),
shipped in [Ansel](https://ansel.photos/en/doc/views/darkroom/modules/photographic-grain/)).
Instead of disks it builds an emulsion: N stacked layers of polygonal crystals,
each layer capturing what light the layers above it left:

    Lₙ(x,y) = I − Σᵢ₌₀ⁿ⁻¹ Lᵢ(x,y),  bounded by the remaining light S(x,y)

Seeds are planted at a density derived in closed form from the target surface
filling ratio, which folds the overlap correction in exactly:

    s = 1 − (1 − f)^(1/A)        A = crystal area in pixels

Numbers from real emulsions: filling ratio **15–30 %** (15 % documented for 1960s
Ilford, ~25 % matches modern stock by eye), **20–30 layers** for monochrome
non-tabular grain and up to **125** for colour tabular (split across three
channels), crystal diameter **0.5–0.7 µm** ≈ 5–13 px in simulation, log-normal
σ **0.25–2.0**. Two results matter to us: the characteristic S-curve *emerges*
from exposure-dependent seeding rather than being applied, and grain is
suppressed in highlights by α = 1 − I. Cost: <8 s single-core for 30 layers on a
1361×2048 image — two to three orders faster than Monte Carlo, still far too slow
for a live canvas.

**The codec model is the cheap one.** Norkin & Birkbeck, *Film Grain Synthesis for
AV1* (DCC 2018, [paper](https://norkin.org/pdf/DCC_2018_AV1_film_grain.pdf)).
An auto-regressive process with lag L ∈ [0,3] generates a **64×64 luma template**
(two 32×32 for chroma), 2L(L+1) coefficients for luma and one more for chroma —
that extra coefficient exists to correlate chroma grain with luma. The template
is applied in 32×32 blocks at pseudo-random offsets, optionally overlapped
because "applying film grain in 32×32 patches can result in visible block
artefacts". Strength is a **piecewise-linear f(Y)**, a 256-entry LUT fit by least
squares to the local standard deviation of flat regions, constrained to f(0) = 0:

    Y′ = Y + f(Y)·G_L
    Cb′ = Cb + f(u)·G_Cb,   u = b·Cb + d·Y_av + h

Everything travels in ≤145 bytes. Avoid the H.264-era frequency-domain method —
that one is a Thomson patent family.

**Practical shader lore.** AMD GPUOpen, *[Fine Art of Film Grain](https://gpuopen.com/learn/vdr-follow-up-fine-art-of-film-grain/)*:
reshape noise with a **high-pass on x and y at different cutoffs**, apply grain
**in linear space before quantisation**, and shape amplitude so grain cannot
raise the black level. Their warning matches ours: visible low-frequency content
and repetitive structure are what the eye catches.

## 2. What shipped

`shaders/grain_overlay.frag` + `core/compose/grain_template.dart`, not the
two-tier Boolean shader the first draft of this document specified. The
constraint that drove that draft — Impeller's `ImageFilter.shader` binds only the
input sampler, so no template texture — dissolved once the overlay was built as
`CustomPainter` + `FragmentShader`, where a second sampler is fine. That put the
AV1 template architecture back on the table, and it won:

- **Dart side** (`GrainTemplate`): a 128×128 field of Box–Muller Gaussian noise,
  band-passed as a difference of Gaussians (σ = 0.55·grainPx minus σ = 1.6·grainPx),
  normalised to zero mean and unit variance, encoded to grey with std ≈ 0.22 so
  ±2.3σ fits without clipping. The convolution wraps, so the tile is seamless.
  Cached per (seed, grainPx).
- **Shader**: two taps of that tile at incommensurate scales (the second at
  0.5309× with a seed-derived offset), summed 1 : 0.6 and renormalised, emitted
  centred on mid-grey and composited with `BlendMode.overlay`. Seamless tiling
  means no block offsets — the un-blended block edges AV1 warns about showed as
  seams when we tried them.
- **Curation**: `GrainSpec{strength, size, seed, matchPx}` per frame. Users never
  see a grain control. Size follows the photo's ISO via `grainPxForIso`.

Judged against the "what reads fake" list, this does well: it has clump energy
rather than white noise, two particle scales rather than one, soft edges from the
template blur, and no visible repetition. Two things it gets wrong, below.

## 3. What's wrong today

**(a) Preview and export didn't show the same grain — fixed 2026-08-22.** The
shader computed `pxy = FlutterFragCoord().xy * uDpr`, where `uDpr` was the
device ratio times the export ratio, so the tile repeated every 128 *device*
pixels: a 4× export rendered the tooth 4× finer relative to the sheet than the
preview the user had tuned by eye, and the tile's repeat crowded in by the same
factor.

Both physical models say a medium's grain is fixed in the medium's own
coordinates. Newson renders the model in input-image coordinates scaled by the
zoom factor s, with σ expressed in output pixels because "the filtering is
related to the observed image, and not the underlying model" — the paper's
selling point is that you can zoom in "to the point where the individual grains
can be observed". Grain does not shrink when you look closer; it resolves.

What it does now (`GrainGeometry`): the export scale picks a template
*magnification* t = ⌈raster⌉, capped at 4. The template is generated t× larger
**and** with a t× larger clump, and the shader samples with `uScale = dpr · t`
over `uTile = 128 · t`. Both the tooth's size on the sheet (`templatePx/uScale`)
and the tile's repeat (`uTile/uScale`) then come out independent of t — the
export spends its extra pixels resolving the same tooth. Past the cap the tile
is magnified rather than regenerated: still the right size, just softer, instead
of an unbounded CPU bill. Export tiles are generated off the UI isolate, and
`rasterizePng` awaits `GrainOverlay.ready()` so it can't rasterise the preview
tile by mistake.

**(b) The tonal response is an accident of the blend mode.** `BlendMode.overlay`
with a grey field g centred on ½ gives, for a base b:

    b < ½:  b′ ≈ b + 2·g·b
    b ≥ ½:  b′ ≈ b + 2·g·(1 − b)

— amplitude peaking at mid-grey and vanishing at both ends. That is the right
*shape*, and it is why the current grain doesn't look flat. But it is fixed (no
per-stock curve), it runs in sRGB rather than linear (GPUOpen: apply before
quantisation, in linear), and it is per-channel: over a saturated red the red
channel takes more grain than the blue, so the grain takes on colour where film's
would not.

Acceptable for paper tooth on a cream sheet — which is all it does today. Not
acceptable once grain lands on a photograph, i.e. when share cards move onto the
engine.

## 4. What to build, ranked

1. ~~Sheet-space grain~~ — done, see §3a.
2. **Explicit f(Y) for photo-bearing surfaces.** Compute luma once, look up
   amplitude from a small piecewise-linear curve (AV1's shape, 8–14 points is
   plenty — they use a 256-entry LUT because it's a decoder), apply on luma so the
   grain stays achromatic. Keeps the overlay path for paper, adds a correct path
   for photographs.
3. **ISO drives amplitude, not size.** `grainPxForIso` currently moves *clump
   size* with ISO, which conflates two axes: clump size is a property of the
   emulsion (crystal diameter), while ISO raises *noise power* — shot noise
   ∝ √e⁻, which is exactly what AV1's photon-noise tables encode (`aomenc
   --photon-noise`, strength 0–64). Keep size per "stock", move amplitude with
   ISO, and the Fuji vocabulary still maps: Weak/Strong → amplitude,
   Small/Large → µ_r.
4. **Colour grain, done the way both sources actually recommend.** Not three
   independent channels: Ansel shares crystal seeds across the B→G→R sub-stacks
   at a default **67 %** and then scales chromatic amplitude separately; AV1
   indexes chroma grain partly off luma and states outright that independent
   multiplicative chroma "was found to not be true for a significant part of
   content". So: one luminance field plus a small decorrelated chroma component
   under a single colourfulness knob (start ~0.2). Two extra taps and a uniform.
5. **Per-stock curves.** Once (2) exists, f(Y) becomes the place a "stock" lives —
   fit from published RMS granularity figures (the standard measure: σ of optical
   density ×1000, typically 5–50) or by eye against scans. This is the axis that
   would let a kata's film simulation carry its own grain.

Deliberately not doing: the full crystal stack (seconds per render, and our
surfaces re-render on every keystroke), neural synthesis (not shader-tractable),
and anything in the H.264 SEI patent family.

## 5. Verification

The shader compiles at build (impellerc); Dart-side template generation is unit
tested for determinism and spec plumbing. The geometry is pinned by a unit test: the
tooth's size and the tile's repeat on the sheet must not move as the export
scale changes. Grain itself is judged by eye at both preview and export scale —
those two should now agree, which is the first thing to check on a real export. Sign-off is Parth's: curation, not measurement.
