# Kata design (from the design tool)

Source project: (design-tool export)
Snapshot: `Kata.dc.html` (2026-08-19, **rev 3**: turn 3 sharing (3a composer + scan-to-import, 3b export templates S1–S4, 3c Kata Code spec) + turn 2 (2a spec sheet, 2b primitives); 1a–1g unchanged). `support.js` / `image-slot.js` are the canvas runtime.

## Contract (from 2a — authoritative metrics)
- Base 4 · grid 8 · gutter 20 (sign-in 28) · themes dark (default) + light.
- Tokens: surface `#000`, surface-sunken `#0A0A0A` (code/JSON, table head), surface-tonal `#1A1A1A` (tonal button, track, tab divider), outline `#2E2E2E`, text-muted `#8A8A8A`, text-secondary `#D9D9D9`, text-primary/accent `#FFF`, alert `#D71921` (overwrite · skipped · invalid — outline + dot only, never fill/body text). Light mirrors: surface `#FFF`, sunken `#F5F5F5`, outline `#D9D9D9`, text `#000`; muted shared.
- Type: Display Doto 800 30–32 upper (hero/empty) · Title Doto 900 24 +5% track · Recipe name Doto 800 18–19/1.05 (slot 14) · Values JetBrains Mono 400 15–16 tabular · Chip/status Mono 500 10.5 upper · Field label Inter 500 8.5 +16% · Body Inter 400/600 11.5–13/1.5 (min 11.5). Rule: Doto = names & headings · Mono = machine values · Inter = sentences.
- Spacing: 4 icon↔label · 8 chip row · 12 card stack/grid · 16 section · 20 gutter.
- Radius: 8 slot · 12 tile · 18 card · 26 sheet · pill. Zero shadows; sheets = hairline + 60% black scrim.
- Sizes: min target 48 · primary CTA H58 R29 · secondary H50–52 · icon button 44⌀ (48 hit) · connect dial 108⌀ · field H42–56 R21 · chip H30 R15 · tab bar H64 · thumb 78sq / hero 168H.
- Motion: tap 90ms linear · sheet 260/180ms · easing cubic(.2,0,0,1) · write dots 1 dot/60ms. Icons: geometric 1.5dp strokes, 16–18 box.
- Component contract: Recipe card R18 pad 13 gap 11, footer = exactly 3 values, incompatible-with-body → opacity .5; Spec cell 3-up row gap 18, label→value 6, track 10H (26 edit), unsupported renders "—" never 0; Slot card R16 pad 12 badge 30sq R9, 2-up gap 11; Status pill H30 R15 pad-x 12, one per app bar; Buttons: primary hover `#FFF→#D9D9D9`, disabled `#1A1A1A` fill + `#8A8A8A` label (never opacity), one primary per screen; Sheet R26 pad 20/22, max 88% viewport, drag-dismiss unless a write is in flight, destructive confirmations modal; Alert card R14–16 pad 12–14 dot 7 gap 9–11.

## Library primitives (from 2b — to add to kata_ui)
Text field (rest/focus/filled/error with eyebrow label, unit suffix, × clear, error caption "OUT OF RANGE −5…+5"); checkbox/radio/switch; segmented control (ALL · MINE · SAVED); stepper (HIGHLIGHT +1); select (GRAIN SIZE · SMALL ▾); determinate progress "14/22 SETTINGS" + indeterminate dot marquee; skeleton loading card; app bar "Detail" + tabs (COLOUR · B&W · MINE 3); list row (title + value/sub, e.g. "Default write slot · Ask each time"), section header (SETTINGS), swipe row with EDIT/DELETE; dialog ("Overwrite C3?" body, Save first / Overwrite), snackbar ("Written to C3 · UNDO"), banner ("!" Turn the dial off C3 and back…), tooltip ("WB shift is R/B, not Kelvin"); menu rows with ✓ (Newest first / Most written / A → Z / Remove from library) and filter sheet row (X-TRANS V); chips: filter/input (ACROS ×)/add (+ FILM SIM)/disabled/count; avatar (HK/FX/M) + "@mireille · 12 katas"; tone strip at 16/32/84; empty state ("0 · Nothing saved yet · Favourite a kata or read one back from your camera. · Browse library"), error ("Camera stopped responding · Nothing was written. Reseat the cable and try again."), permission ("Allow Kata to access this USB device? · Allow"), image slot.

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

## Sharing (from turn 3 — Stage 2b)
- **3a Composer:** preview of the share card; template row `S1 CARD · S2 SHEET · S3 STORY · S4 CODE`; options: Invert card, Embed Kata Code, Credit (`@handle ›`), Ratio `4:5 · 1:1 · 9:16`; `{ }` raw-payload peek; primary **Share card**. **Scan-to-import:** viewfinder "SCAN A KATA CODE · PASTE INSTEAD — Point at the code on any Kata card — no network needed"; decoded preview card (name, `NOSTALGIC NEG · DR100 · WB SHIFT`, "from @heikki.k · 22 settings decoded", "Read straight from the image — the code carries the recipe, not a link"); actions **Review fields** / **Save to mine**.
- **3b Templates:** S1 recipe card (name, sim·sensor, 2-col value list, credit, "SCAN TO IMPORT · 22 SETTINGS", optional shoot meta `12 DEC 2022 · PARIS / X-T5 · 56MM F1.4`); S2 contact sheet (photo grid + compact values + hashtags); S3 story 9:16 (big name, few values, "SCAN TO LOAD INTO YOUR OWN C-SLOT"); S4 code-only (name, summary, credit, large code, HOW TO USE).
- **3c Kata Code:** QR whose payload *is* the recipe (not a link). Payload ~180–260 B, QR v6 ECC M, min 24 mm / 96 px, quiet zone 4 modules, always monochrome (inversion allowed, no tint, no centre logo, never over a photo). Format: `kata1:` + fixed-order abbreviated fields (omitted = camera default) + `;n=<name>;a=<credit>;v=<sensor gen>` — e.g. `kata1:CC,DR400,WB5800/+2-3,H+1,S-0.5,C+2,SH+1,NR-4,CL0,GR-WS,CCR-S,CCB-W;n=Kodachrome+64;a=heikki.k;v=xt5`. Sizes: card 36 · sheet 56 · poster 76+. Fallbacks: paste text (same string), optional short link `kata.app/k/…` resolving to the same payload, `.ofr.json` for archives. Cross-sensor codes import with unsupported fields flagged and skipped on write — never silently coerced.

## Implementation notes (Plan 2, 2026-08-19)
- `packages/kata_ui` implements tokens/theme + every 1g/2b component used by Stage 1; fonts bundled (Doto/Inter/JetBrains Mono, OFL). Kit screen at `/kit` (Profile → Component kit) renders the whole set for eyeballing.
- Verified on Pixel 7 Pro (release build): sign-in, library (hero + compact cards, chips, sort), detail (hero scrim, spec grid + rulers, NO CAMERA pill, disabled CTA), camera tab checklist + Connect dial, Mine segmented + empty state. Light theme follows system.
- Deltas vs canvas: no sample photos yet (FrameSlot placeholders everywhere — `imageUrls` arrives with the backend); "ON DIAL" slot state not shown (no wire signal for the dial-selected slot); offline banner omitted until the API exists; camera line-art is the hatched placeholder from 1d.
- Test-font note: widget tests run with the Ahem font (every glyph a wide square), so rows must be Flexible/ellipsis-safe — several kit widgets were hardened for that.

## Implementation notes (Plan 3b, 2026-08-19)
- App ↔ API wired: `ApiClient` (dio, bearer + single-flight refresh, 401 → session lost), `AuthRepository`/`sessionProvider` (Google ID token → `/auth/google`, tokens in secure storage, `/me` on restore), `RecipeRepository` (drift cache: `cached_recipes`/`mine_recipes`/`favourites`/`meta`; cache-first, full page-through sync, stale-id delete, `lastSyncedAt`, `offline` flag). Library: offline card + RETRY, pull-to-refresh, Bunny images via `CachedNetworkImageProvider`. Motion: `KataMotion` tokens, tap-scale on buttons/cards, staggered fade-in, animated dot matrix, fade+rise page transitions, sheet timing — all skipped under reduce-motion.
- Verified on Pixel 7 Pro (release build, **no** `KATA_GOOGLE_WEB_CLIENT_ID`): boots to sign-in; "Continue with Google" → toast "Google sign-in isn't configured in this build"; long-press the 型 mark → probe screen (debug routes `/probe`, `/kit` allowed signed-out) → **Ping API** → `GET https://api.kata.parthjansari.dev/health → {ok: true, …} (913 ms)` over TLS from the phone. Library/auth paths are covered by widget tests against `FakeRecipeApi`/`FakeGoogle` + the in-memory drift db (32 app tests, 13 kata_ui tests).
- Google OAuth clients created (Android: package `dev.parth.kata`, debug SHA-1 `2B:CA:…:31:C0`; Web client ID set in VM `/opt/kata/api/.env` `GOOGLE_WEB_CLIENT_ID` + `pm2 reload kata-api --update-env`; build with `--dart-define=KATA_GOOGLE_WEB_CLIENT_ID=<web id>`). **Verified on the Pixel**: Continue with Google → system account picker → consent → `/auth/google` → library synced with the 340 seeded Fuji X Weekly recipes (verified badges, sensors, attribution) → detail renders real data. Still to run by hand: airplane-mode banner → RETRY, write to the X-S20, Profile/sign-out (toggling airplane mode over wireless adb drops the adb link — do it on the phone).
- Bottom nav reworked after feedback ("icons confusing"): line icons that read as *stacked cards / camera body / bookmark / person* + 8px mono labels LIBRARY · CAMERA · MINE · PROFILE, dot under the active tab.
- Deltas: Mine/imported recipes are still device-local (Stage 2 publishes them); seeded recipes have no photos yet (FrameSlot placeholders until Bunny images are attached); release `R8` keeps working without a `google-services.json` (google_sign_in v7 uses Credential Manager).

## Implementation notes (Plan 4 landing, 2026-08-19)
- Live at https://kata.parthjansari.dev — static `web/landing/` (HTML + CSS, no build), deployed by `web/deploy.sh`; `/kata.apk` serves the current release build (`downloads/kata-<version>.apk` + symlink, nginx `application/vnd.android.package-archive`), QR in the Get section encodes that URL. `privacy.html` added (linked from footer + for the OAuth consent screen).
- Honesty edits vs the design: stats show the real count (340); slots column notes C1–C4 on X-S20 / X-S10 / X-T30 II; write-support chips: X-Trans V "FULL · TESTED ON X-S20", IV "FULL · UNTESTED", GFX "MOST FIELDS", III "READ ONLY" + a note that other bodies are flagged until confirmed; Kata Code section kept but pilled `ROADMAP · NEXT RELEASE`; "Everything, free" drops batch-write / version-history claims and marks share cards + publishing as next release; "OPEN SOURCE" added to the free pill; footer "NOT AFFILIATED WITH FUJIFILM CORPORATION" kept.
- Deltas: all image slots are dot-grid placeholders (no permitted photos yet); recipe-card credit shows "Fuji X Weekly" instead of a handle; no JS at all (anchors + smooth scroll via CSS, nav links hide ≤ 720px).
- Checked at 1280 and 390 px widths via Playwright: no horizontal overflow, table scrolls inside its own box on phones.

## Admin console (the design tool file `Kata Admin.dc.html`, 1440×940 web)
- Layout: left sidebar 236px (wordmark `型 KATA / ADMIN`; nav: **Review queue** (count badge), Recipes, Creators, Reports (red count), Camera profiles, Kata Codes, Settings; bottom card "WRITE SUCCESS · 7D" bar chart + `98.2%`; curator avatar). Main: header "REVIEW QUEUE · 14 SUBMITTED · 3 REPORTED · OLDEST 2D 4H", search (recipes/creators/codes), sensor filter pill, primary "New camera profile"; 4 stat cards (Pending review 14 / Published katas 128 · 41 verified / Code scans 7d 9,412 · 78% offline / Failed writes 7d 63 · red outline, "X-H2 FW 2.0"); chips PENDING 14 · REPORTED 3 · PUBLISHED; bulk actions "2 SELECTED · APPROVE BOTH · REJECT(red)"; table (checkbox, KATA thumb+name+sim·DR, CREATOR avatar+handle, SENSOR, FIELDS `22/22` (red when invalid), STATUS pill PENDING/IN REVIEW/2 INVALID(red)/VERIFIED/DRAFT); pagination "SHOWING 1–6 OF 14". Right pane 378px: "SUBMISSION · <name>", 3 thumbs, name + "Fuji X Weekly · submitted 2d ago" + swatch, VALIDATION checklist (✓ fields in range for sensor, ✓ source URL reachable + attribution, ! near-duplicate 91% match), PAYLOAD 6-cell spec grid, Kata Code preview card (`214 BYTES · QR V6 · ECC M` · TEST), actions **APPROVE** (+ ✓✓ approve-and-verify), Request changes, Reject (red).
- Implies backend (Stage 3): review queue endpoints (pending/reported/published lists, approve/verify/reject/request-changes, bulk), reports, creators list, camera-profile CRUD (per-generation supported fields), write-success + scan telemetry, near-duplicate detection (hash + settings distance). Admin is a web app (Plan 5) — same tokens, desktop density (12.5px body, 10.5 mono chips, 40px nav rows, table gap 1px on `#1A1A1A`).

## Landing page (the design tool file `Kata Landing.dc.html`, responsive web, 1200 max-width)
- Sticky nav (型 KATA; HOW IT WORKS · KATA CODE · CAMERAS · WHAT'S INCLUDED; "Get Kata"). Hero on dot-grid bg: pill "ANDROID · USB-C · FREE, EVERY FEATURE", h1 Doto 68 "STOP RETYPING FILM RECIPES", copy "Kata keeps every film-simulation recipe you love in one library and writes it straight into your Fujifilm's C1–C7 over USB-C. Twenty-two menu items, one tap.", CTAs "GET KATA FREE" (Doto pill) + "See how it works", stats 128 recipes · 22 settings per write · 0 menu dives; 4-image masonry right.
- Film-sim marquee strip; **How it works** 3 cards (1 FIND Pick a kata · 2 CONNECT Plug in USB-C (slot cards C1/C2) · 3 WRITE One tap, 22 settings (dot matrix "WRITING 18/22 → C3")); **The Kata Code** section on `#0A0A0A` with payload block + bullets + a white S1 recipe card mock; **Bodies & slots** table (X-Trans V / IV / GFX / III: example bodies, C1–C7, film sims 20/18/19/15, write support FULL/FULL/MOST FIELDS/READ ONLY); **Everything, free** 3 cards (SHOOT/SHARE/KEEP); CTA "THE FORM YOU FALL BACK ON" + "GET IT ON ANDROID" + QR "SCAN TO INSTALL"; footer with "NOT AFFILIATED WITH FUJIFILM CORPORATION".
- Implies: static site at `kata.parthjansari.dev/` (so the API moves under `/api`), admin SPA at `/admin`. Copy claims to keep honest at launch: slot counts per body (X-S20 = C1–C4, not C7), "batch write every slot" and "version history" are roadmap.
