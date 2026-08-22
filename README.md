# Kata

Fujifilm film-simulation recipes, written straight into your camera's custom slots (C1–C7) over
USB-C. Pick a recipe on the phone or the desktop, plug the camera in, press write — instead of
typing twenty-two menu items by hand.

- **Site + library:** <https://kata.parthjansari.dev>
- **Recipe format:** [Open Fuji Recipe](https://github.com/gosku/open-fuji-recipe) (OFR)
- **Licence:** MIT

The starting library is 341 recipes from [Fuji X Weekly](https://fujixweekly.com), imported with
credit and a link back to every original post. Ritchie Roesch works those recipes out on real
cameras and gives them away free — if you shoot with them, consider becoming an
[App Patron](https://fujixweekly.com/2021/10/22/why-should-you-become-a-fuji-x-weekly-app-patron/).

Not affiliated with Fujifilm Corporation.

## What's here

| Path | What it is |
|---|---|
| `app/` | The Flutter app — Android and Linux desktop from one codebase |
| `packages/fuji_ptp/` | PTP over USB for Fujifilm bodies: transport, the Custom Settings protocol (read / write / verify), the Android USB-host bridge and a libusb host for desktop |
| `packages/ofr/` | The Open Fuji Recipe model, hashing, and the **Kata Code** codec (`kata1:…`) |
| `packages/kata_ui/` | The design system: tokens, type, primitives |
| `backend/` | NestJS + Prisma + Postgres API — library, publishing, favourites, review queue |
| `web/landing/` | The site |
| `web/lib/` | The web library (React) |
| `web/admin/` | The curator console (React) |
| `docs/` | Protocol research, design notes, ops runbooks |
| `probe/` | The throwaway USB probe that worked the protocol out in the first place |

## How the camera part works

Fujifilm bodies expose their Custom Settings banks as PTP device properties (`0xD18C`–`0xD1A5`)
when the camera is set to `USB RAW CONV./BACKUP RESTORE` — the same surface Fujifilm's own X RAW
Studio uses. Kata selects a slot, reads it back, writes the recipe's properties in X RAW Studio's
order, then reads every one of them again to verify. Nothing is written until you approve a
field-by-field diff, and the slot is snapshotted first so a write can be undone.

What each body accepts differs, so unsupported fields are skipped and named rather than coerced —
and when a camera refuses a setting it *does* have (HDR locks the tone curve, for instance), the
app says which mode to turn off. `docs/fuji-usb-research.md` has the protocol notes, including
what is still unknown.

Verified end-to-end on an X-S20. Other X-Processor 5 bodies expose the same protocol and are
expected to work; older bodies are probed at connect and told apart honestly.

## Building it

```bash
# the app (Flutter 3.41 / Dart 3.11, fvm optional)
cd app && flutter pub get
flutter run -d linux            # or -d <android device>
flutter test

# Linux packages
packaging/linux/build-deb.sh
APPIMAGETOOL=/path/to/appimagetool packaging/linux/build-appimage.sh

# the API
cd backend && npm ci
cp .env.example .env            # DATABASE_URL, JWT_SECRET, GOOGLE_WEB_CLIENT_ID, Bunny keys
npm run prisma:migrate && npm run start:dev
npm test && npm run test:e2e

# the web library / admin console
cd web/lib && npm ci && npm run dev
```

Sign-in is Google; each platform's client ids live in a per-OS secrets file passed with
`--dart-define-from-file=secrets/<os>.json` — see `app/secrets/README.md` (templates are
committed, real files are not). Deploy scripts want `KATA_HOST=user@host`.

On Linux the camera needs a udev rule once — the `.deb` installs it; otherwise see
`docs/ops/kata-desktop.md`.

## Kata Code

A recipe as text, small enough for a QR code, readable without one:

```
kata1:CC,DR400,WB5800/+2-3,HL+1,SD-0.5,CO+2,SH+1,NR-4,GR-WS;n=Kodachrome+64;a=Fuji+X+Weekly
```

`HL` highlight · `SD` shadow · `CO` colour · `SH` sharpness · `CL` clarity · `NR` noise reduction ·
`GR` grain · `WB` white balance and shift. The code *contains* the recipe rather than linking to
one, so it imports offline, with no account and no URL to rot. Codec in `packages/ofr`, encoder
mirrored for the web in `web/lib/src/kataCode.ts`.
