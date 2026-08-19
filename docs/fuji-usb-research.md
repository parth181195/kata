# Fujifilm camera ↔ Android over USB — research for an OFR-based recipe app

Compiled 2026-08-19. Goal: an Android app that reads/writes Fujifilm **Custom Settings (C1–C7)** over USB-C and exchanges recipes with other apps using the **Open Fuji Recipe (OFR)** JSON spec.

---

## 0. TL;DR

| Topic | Answer |
|---|---|
| Protocol | Plain **PTP (ISO 15740) over USB bulk transfers**, with Fujifilm vendor **device properties** `0xD18C–0xD1A5`. Same thing X RAW Studio / X Acquire use. No vendor *operations* needed for presets — only `GetDevicePropValue` (0x1015) / `SetDevicePropValue` (0x1016). |
| USB identity | VID `0x04CB` (Fujifilm). Interface 0, one bulk IN + one bulk OUT endpoint (class 6 "Still Image"/PTP). |
| Camera setting | `CONNECTION SETTING → CONNECTION MODE → USB RAW CONV./BACKUP RESTORE`. (Not CARD READER, not TETHER.) |
| Cameras | Preset read/write confirmed on **X100VI** (FilmKit) and **X-S20 fw 3.30 from a Pixel 7 Pro** (our probe, 2026-08-19); the `D18C` preset properties appear on **X-Processor 5 / X-Trans V** bodies (X-T5, X-H2, X-H2S, X-S20, X-T50, X-M5, X-E5, X-T30 III, X100VI, GFX100 II, GFX100S II, GFX100RF). Older bodies (X-T4/X-T30/X100V) support the RAW-conversion protocol but may **not** advertise `D18C`. Check `GetDeviceInfo.DevicePropertiesSupported` at runtime. |
| Android transport | `android.hardware.usb` host API (`UsbManager` → `UsbDeviceConnection.bulkTransfer`). Phone must be USB host (OTG). Hand-rolling PTP is ~300 lines; FilmKit proves it works on Android (via Chrome WebUSB). |
| Best reference impl | **eggricesoy/filmkit** (MIT, TypeScript) — the only public source with the decoded preset property table. Clone is in scratchpad; port `ptp/*.ts` + `profile/*.ts` to Kotlin. |
| OFR | Draft v1, JSON, spec is the README only (no tooling, no license file, 0 stars, 1 open PR changing the hash rule). Treat as moving target; pin to a commit. |

---

## 1. Camera-side facts

### 1.1 Connection mode
Camera menu: **CONNECTION SETTING → CONNECTION MODE → USB RAW CONV./BACKUP RESTORE**.
This is the mode X RAW Studio and X Acquire require; FujiStyle (Android app) documents the same for recipe sync, with a note that the X-M5 may need **USB TETHER SHOOTING (FIXED)** instead. Other modes:
- `USB CARD READER` — camera exposes MTP/PTP *storage* (what Android's built-in "Camera Importer" uses). Preset props may not be reachable.
- `USB TETHER SHOOTING AUTO/FIXED` — tethering (libgphoto2 path); exposes shooting props (0xD0xx/0xD2xx).
- `USB WEBCAM` — UVC, irrelevant.

Also: `USB POWER SUPPLY/COMM SETTING` → `AUTO` or `POWER SUPPLY OFF/COMM ON` (on X-T5 etc.). FujiStyle also reports recipes show "invalid" unless the camera is in **M** (manual) mode — unverified, but worth surfacing in UI.

### 1.2 Cable / OTG
- Data-capable USB-C↔USB-C cable (or A→C + OTG adapter for micro-B phones). Charge-only cables fail silently.
- Phone must act as **USB host**; the camera is a peripheral only. Most modern phones are fine; some need OTG enabled in settings and auto-disable it after idle.
- Close other apps that grab USB (file managers, gallery importers). Only one process can claim interface 0.

### 1.3 Known Fujifilm USB product IDs (VID 0x04CB)
From libgphoto2 `camlibs/ptp2/library.c`:

| PID | Body | PID | Body |
|---|---|---|---|
| 0x02cb | X-Pro2 | 0x02ea | X-S10 / GFX100S |
| 0x02cd | X-T2 | 0x02f0 | X-H2S |
| 0x02d1 | X100F | 0x02f2 | X-H2 |
| 0x02d3 | GFX 50S | 0x02fc | **X-T5** |
| 0x02d4 | X-T20 | 0x02fe | **GFX100 II** |
| 0x02d6 | X-E3 | 0x0305 | **X100VI** |
| 0x02d7 | X-H1 | 0x030c | **X-M5** |
| 0x02dc | GFX 50R | 0x0313 | **X-E5** |
| 0x02dd | X-T3 | — | X-T50, X-T30 III, GFX100S II, GFX100RF: PIDs not in libgphoto2 yet — **filter by VID only** |
| 0x02de | GFX100 | | |
| 0x02e3 | X-T30 | | |
| 0x02e4 | X-Pro3 | | |
| 0x02e5 | X100V | **0x02f7** | **X-S20** (probe-confirmed) |
| 0x02e6 / 0x02e7 | X-T4 | | |
| 0x02e8 | X-E4 | | |

→ In `device_filter.xml` match on `vendor-id="1227"` only, then identify the model from PTP `GetDeviceInfo.Model` string.

---

## 2. PTP over USB — wire format

### 2.1 Container
```
[0..3]  uint32 LE  length (header + payload)
[4..5]  uint16 LE  type   1=Command 2=Data 3=Response 4=Event
[6..7]  uint16 LE  code   (opcode / response code)
[8..11] uint32 LE  transaction id
[12..]  Command/Response: up to 5 × uint32 params
        Data: raw payload
```
Transaction id starts at 0, increments per command (Command + optional Data + Response share the id). Reset to 0 when you re-open the USB connection.

### 2.2 Phases
- **Command without data** (`GetDevicePropValue`): send CMD → recv (maybe DATA) → recv RESPONSE.
- **Command with data out** (`SetDevicePropValue`): send CMD → send DATA → recv RESPONSE.
- Large reads: first `bulkTransfer` gives you the header; loop until `length` bytes collected. FilmKit uses 512 KB chunks both ways.

### 2.3 Opcodes / codes you need
| Name | Code |
|---|---|
| GetDeviceInfo | 0x1001 |
| OpenSession | 0x1002 (param: session id = 1) |
| CloseSession | 0x1003 |
| GetObjectHandles | 0x1007 |
| GetObject | 0x1009 |
| DeleteObject | 0x100B |
| GetDevicePropDesc | 0x1014 |
| GetDevicePropValue | 0x1015 (param: prop code) |
| SetDevicePropValue | 0x1016 (param: prop code; data = value bytes) |
| Fuji SendObjectInfo | 0x900C (RAF upload only) |
| Fuji SendObject2 | 0x900D (RAF upload only) |
| Resp OK | 0x2001 |
| Resp SessionAlreadyOpen | 0x201E |
| Resp DevicePropNotSupported | 0x200A |

### 2.4 Session handling gotchas (from FilmKit)
- Camera remembers a stale session if the previous app died → `OpenSession` returns `0x201E`. Recovery: `CloseSession`, release+reopen USB connection (reset transaction ids), `OpenSession` again.
- Send `CloseSession` on disconnect/app background (best effort).
- Heartbeat: `GetDevicePropValue(0xD212 CurrentState)` every few seconds to detect unplug.
- `GetDeviceInfo` payload layout: `u16 StandardVersion, u32 VendorExtID (0xE for Fuji), u16 VendorExtVer, str VendorExtDesc, u16 FunctionalMode, u16[] ops, u16[] events, u16[] props, u16[] captureFormats, u16[] imageFormats, str Manufacturer, str Model, str DeviceVersion, str Serial`. PTP string = `u8 numChars` + UCS-2LE chars incl. NUL terminator; arrays = `u32 count` + elements.

---

## 3. Custom-settings (preset) protocol — `0xD18C–0xD1A5`

Source: FilmKit (`src/ptp/constants.ts`, `src/profile/preset-translate.ts`), derived from Wireshark captures of X RAW Studio ↔ X100VI (2026-03). **Not in libgphoto2.** Treat as "confirmed on X100VI, likely identical on other X-Processor 5 bodies".

### 3.1 Procedure
```
OpenSession(1)
Set D18C = slot (u16, 1..7)          ← selects which C-slot the other props address
sleep ~100 ms
[read]  Get D18D (name, PTP string); Get D18E..D1A5 each (mostly 2-byte int16/uint16)
[write] Set D18D = name (PTP string) ; Set each prop in the ORDER below ; re-read to verify
restore D18C to the original slot
CloseSession
```
All values are 2-byte little-endian unless noted. FilmKit reads every prop as int16 — for WB/NR mask with `0xFFFF`.

### 3.2 Property table
| Prop | Meaning | Encoding | R/W notes |
|---|---|---|---|
| D18C | Preset slot selector | u16 1–7 | write first; X-S20 accepts 1–4, rejects 5–7 with DevicePropNotSupported |
| D18D | Preset name | PTP string | X-S20 returns empty string for all slots (body has no custom names); X100VI has names |
| D18E | Image size | u16 (7 = L 3:2 observed) | keep camera value |
| D18F | Image quality | u16 (4 observed) | keep camera value |
| D190 | Dynamic range | **raw %: 100 / 200 / 400; DR-Auto = 0xFFFF (−1)** | DR-Auto confirmed on X-S20 (read) — write still to be tested |
| D191 | ? | always 0 | unknown — candidate for D-Range Priority? |
| D192 | Film simulation | u16, see §4.1 | |
| D193 | Monochromatic color Warm/Cool | int16 ×10 (−90..+90) | only B&W sims; **camera rejects writing 0** → omit when 0 |
| D194 | Monochromatic color Magenta/Green | int16 ×10 | same rules as D193 |
| D195 | Grain | flat enum: 1 Off, 2 Weak/Small, 3 Strong/Small, 4 Weak/Large, 5 Strong/Large | |
| D196 | Color Chrome Effect | 1 Off, 2 Weak, 3 Strong | |
| D197 | Color Chrome FX Blue | 1 Off, 2 Weak, 3 Strong | |
| D198 | Smooth Skin Effect | 1 Off, 2 Weak, 3 Strong | **absent on X-S20** (DevicePropNotSupported) — check DeviceInfo before writing |
| D199 | White balance mode | u16 enum, see §4.2 | write **before** D19C |
| D19A | WB shift Red | int16 −9..+9 | written after D19C by official app |
| D19B | WB shift Blue | int16 −9..+9 | |
| D19C | WB color temperature (K) | u16 2500–10000 | readable always (X-S20 returns stored K even under WB Auto); **only writable when D199 = 0x8007 (Color Temp)** |
| D19D | Highlight tone | int16 ×10 (−20..+40) | 0x8000 = sentinel ("unset") |
| D19E | Shadow tone | int16 ×10 (−20..+40) | |
| D19F | Color | int16 ×10 (−40..+40) | **rejected for monochrome sims** → omit |
| D1A0 | Sharpness | int16 ×10 (−40..+40) | |
| D1A1 | High ISO NR | **proprietary**: −4→0x8000, −3→0x7000, −2→0x4000, −1→0x3000, 0→0x2000, +1→0x1000, +2→0x0000, +3→0x6000, +4→0x5000 | |
| D1A2 | Clarity | int16 ×10 (−50..+50) | |
| D1A3 | Long exposure NR | 1 = On | keep camera value |
| D1A4 | Color space | 1 sRGB, 2 AdobeRGB | keep camera value |
| D1A5 | ? | always 7 | keep camera value |

**Write order used by X RAW Studio (replicate it):** D18E, D18F, D190, D191, D192, [D193, D194 if mono & ≠0], D195, D196, D197, D198, D199, [D19C if WB=ColorTemp], D19A, D19B, D19D, D19E, [D19F if not mono], D1A0, D1A1, D1A2, D1A3, D1A4, D1A5.

Individual `SetDevicePropValue` failures are non-fatal (some props are read-only on some bodies); slot-select or name failure is fatal. Verify by reading back and byte-comparing.

### 3.3 Things the preset props do NOT cover (gaps vs. recipes)
- **D-Range Priority** (Off/Auto/Weak/Strong) — no confirmed preset prop. In the RAW-conversion profile (`0xD185`) it's field `[7] WideDRange`. `D191` (always 0) is the best guess; needs a capture with DRP ≠ Off.
- ~~**DR-Auto**~~ — resolved: D190 = 0xFFFF on slots set to DR-Auto (X-S20). Write path untested.
- **WB "Auto (white priority)"** — value unknown (ambience priority = 0x8021, so white priority is probably 0x8020; unverified).
- **Custom WB 1–3** — libgphoto2 says 0x8008/0x8009/0x800A for Fuji WB; not verified on preset props.
- Exposure comp., ISO, etc. are not part of C-slot image-quality settings over this channel.

→ Plan for a Wireshark/usbmon capture session on your own body to close these; FilmKit's README has the capture procedure.

---

## 4. Enumerations

### 4.1 Film simulation (D192, also RAF/EXIF)
1 Provia · 2 Velvia · 3 Astia · 4 Pro Neg Hi · 5 Pro Neg Std · 6 Monochrome · 7 Mono+Ye · 8 Mono+R · 9 Mono+G · 10 Sepia · 11 Classic Chrome · 12 Acros · 13 Acros+Ye · 14 Acros+R · 15 Acros+G · 16 Eterna · 17 Classic Neg · 18 Eterna Bleach Bypass · 19 Nostalgic Neg · 20 Reala Ace
(1–18 agree with libgphoto2 `fuji_filmsimulation[]`; 19–20 from FilmKit.)
Monochrome set: {6,7,8,9,10,12,13,14,15}.

### 4.2 White balance (D199)
| Value | Mode |
|---|---|
| 0x0002 | Auto |
| 0x8021 | Auto (ambience priority) — confirmed |
| 0x8020 ? | Auto (white priority) — **unverified guess** |
| 0x0004 | Daylight |
| 0x8006 | Shade |
| 0x0006 | Incandescent |
| 0x8001 / 0x8002 / 0x8003 | Fluorescent 1 / 2 / 3 |
| 0x8007 | Color temperature (Kelvin) → also write D19C |
| 0x0008 | Underwater |
| 0x8008 / 0x8009 / 0x800A | Custom 1 / 2 / 3 (libgphoto2; unverified for presets) |
| 0x0000 | "As shot" (RAW-conv only, not a preset value) |

### 4.3 Others
- Grain (D195): 1 Off · 2 Weak+Small · 3 Strong+Small · 4 Weak+Large · 5 Strong+Large
- Off/Weak/Strong triplets (D196/D197/D198): 1/2/3
- Tone/Color/Sharpness/Clarity/MonoWC/MonoMG: value ×10 as int16; 0x8000 = "unset" sentinel when reading
- High ISO NR (D1A1): lookup table in §3.2

---

## 5. Open Fuji Recipe (OFR) v1 — summary

Repo: https://github.com/gosku/open-fuji-recipe (README-only spec, draft, no license file, last update 2026-07-26). One open PR (#1, by the author) proposes: hash **settings only** (exclude `sensors`), and `sources` as an array. Pin to a commit and keep the hasher swappable.

### 5.1 Shape
```json
{
  "v": 1,
  "hash": "<sha256 hex>",
  "name": "Kodachrome 64",                 // ≤25 ASCII
  "sensors": ["X-Trans IV"],
  "source_url": "...", "source_attribution": "...",

  "film_simulation": "Classic Chrome",
  "dynamic_range": "DR400",                // DR100|DR200|DR400|DR-Auto  (omit if DRP≠Off)
  "d_range_priority": "Off",               // Off|Auto|Weak|Strong (required)
  "grain_roughness": "Weak", "grain_size": "Small",   // size omitted when Off
  "color_chrome_effect": "Weak", "color_chrome_fx_blue": "Off",  // omit for mono
  "white_balance": "Daylight", "wb_kelvin": 5500,     // kelvin only when "Kelvin"
  "white_balance_red": 2, "white_balance_blue": -5,   // -9..+9
  "highlight": -1, "shadow": 0.5,          // -2..+4 half steps; omit if DRP≠Off
  "color": 2,                              // -4..+4; omit for mono
  "sharpness": -2, "high_iso_nr": -4, "clarity": 0,
  "monochromatic_color_warm_cool": 0, "monochromatic_color_magenta_green": 0  // mono only
}
```
Enums: film sims — `Provia, Velvia, Astia, Classic Chrome, Pro Neg. Hi, Pro Neg. Std, Classic Negative, Eterna, Eterna Bleach Bypass, Nostalgic Negative, Reala Ace, Acros STD/Yellow/Red/Green, Monochrome STD/Yellow/Red/Green, Sepia`. WB — `Auto, Auto (white priority), Auto (ambience priority), Daylight, Shade, Incandescent, Fluorescent 1/2/3, Kelvin, Underwater, Custom 1/2/3`. Sensors — `X-Trans I..V, GFX, Bayer, EXR-CMOS, Full Spectrum`.

Omission rules: absent, never `null`. Unknown `v` → reject.

### 5.2 Hash (current README)
1. Take all settings fields present + `sensors` (empty array if absent)
2. Sort keys alphabetically (top-level only)
3. Compact JSON (no whitespace) — note: numbers must serialize canonically (`0.5` not `0.50`, `2` not `2.0`)
4. UTF-8 → SHA-256 → lowercase hex

Kotlin sketch:
```kotlin
fun ofrHash(doc: JsonObject): String {
    val envelope = setOf("v", "hash", "name", "source_url", "source_attribution")
    val payload = doc.filterKeys { it !in envelope }.toMutableMap()
    payload.putIfAbsent("sensors", JsonArray(emptyList()))
    val canonical = JsonObject(payload.toSortedMap()).toString() // kotlinx.serialization is compact by default
    return MessageDigest.getInstance("SHA-256").digest(canonical.toByteArray(Charsets.UTF_8))
        .joinToString("") { "%02x".format(it) }
}
```
(PR #1 would drop `sensors` from the payload — keep this behind a version flag.)

### 5.3 OFR ↔ PTP preset mapping
| OFR field | PTP prop | Transform |
|---|---|---|
| `film_simulation` | D192 | name → code (§4.1); "Acros STD"→12, "Monochrome STD"→6, "Classic Negative"→17, "Nostalgic Negative"→19 |
| `dynamic_range` | D190 | `DR100/200/400` → 100/200/400; `DR-Auto` → **unknown** |
| `d_range_priority` | ? (D191?) | **unknown on wire** — if ≠Off, warn user / write DR100 fallback |
| `grain_roughness` + `grain_size` | D195 | Off→1; Weak/Small→2; Strong/Small→3; Weak/Large→4; Strong/Large→5 |
| `color_chrome_effect` | D196 | Off/Weak/Strong → 1/2/3 (skip for mono) |
| `color_chrome_fx_blue` | D197 | Off/Weak/Strong → 1/2/3 (skip for mono) |
| `white_balance` | D199 | name → code (§4.2) |
| `wb_kelvin` | D19C | only when WB=Kelvin (0x8007); write right after D199 |
| `white_balance_red/blue` | D19A / D19B | int16 as-is |
| `highlight` / `shadow` | D19D / D19E | ×10 (0.5 → 5) |
| `color` | D19F | ×10; omit for mono |
| `sharpness` | D1A0 | ×10 |
| `high_iso_nr` | D1A1 | lookup table (§3.2) |
| `clarity` | D1A2 | ×10 |
| `monochromatic_color_warm_cool/magenta_green` | D193 / D194 | ×10; omit when 0 or not mono |
| `name` | D18D | PTP string; truncate to camera limit |
| `sensors` | — | derive from `GetDeviceInfo.Model` for export (X-Trans V for all current USB-writable bodies) |
| (no OFR field) | D198 Smooth Skin, D18E/F, D1A3/4/5 | keep existing slot values |

Reverse (camera → OFR): everything maps back except sentinel 0x8000 values (treat as 0/default) and the unknown DRP/DR-Auto encodings.

---

## 6. Android implementation notes

### 6.1 Manifest / discovery
```xml
<uses-feature android:name="android.hardware.usb.host" android:required="true"/>
<activity ...>
  <intent-filter><action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED"/></intent-filter>
  <meta-data android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" android:resource="@xml/device_filter"/>
</activity>
```
`res/xml/device_filter.xml`: `<usb-device vendor-id="1227" />` (0x04CB). Optionally add `class="6" subclass="1" protocol="1"` (PTP still-image class) — but filter on VID to be safe with bodies that report vendor-specific class.

### 6.2 Connect sequence
1. `UsbManager.deviceList` → pick VID 0x04CB; `requestPermission()` via PendingIntent (or launched from ATTACHED intent, already granted).
2. `openDevice()` → `UsbDeviceConnection`; find interface 0 → bulk IN / bulk OUT endpoints; `claimInterface(intf, /*force=*/true)` (force detaches Android's MTP host driver if it grabbed the device).
3. Implement PTP container send/recv over `bulkTransfer(ep, buf, len, timeoutMs)` (Android ≥ 28 supports offset+length; use ≤ 16 KB per call on old devices, larger on modern — chunk anyway). Run on a dedicated single-threaded dispatcher; serialize all camera I/O behind a queue (FilmKit's command-queue pattern).
4. `OpenSession(1)` with the 0x201E recovery path; `GetDeviceInfo`; check `0xD18C ∈ props` → enable preset features.
5. Register `USB_DEVICE_DETACHED` receiver; `CloseSession` + `releaseInterface` + `close()` in `onStop`/detach.

### 6.3 Pitfalls
- **Android MTP host** (`UsbManager`/"Camera Importer") may auto-claim the camera when it shows up in CARD READER mode; in RAW CONV mode it usually still enumerates as PTP. `claimInterface(force=true)` handles it.
- Android `android.mtp.MtpDevice` is **not** usable — it has no raw `SetDevicePropValue` with arbitrary payloads. Roll your own PTP or wrap a C lib (petabyt **camlib**/fudge, libgphoto2 via NDK+libusb — heavier than needed).
- Existing Java/Kotlin PTP-over-USB references: `michaelzoech/remoteyourcam-usb` (`PtpUsbConnection.java`), `laheller/ptplibrary`, `terencehonles/Android_USB_PTP_Lib`. All Canon/Nikon-centric; reuse the transport, not the command sets.
- Large reads (RAF/JPEG for preview rendering) → loop `bulkTransfer` until container length satisfied; 30–60 s timeouts.
- USB-C role: if the phone negotiates as *device* (e.g. some Samsung + camera combos), nothing enumerates. Tell user to try replugging / a different cable.
- Commercial apps already doing this on Android: **Fuji Recipes** (fujirecipes.co), **FujiStyle** — evidence the approach is viable in production.

### 6.4 Suggested module layout (Kotlin)
```
:ptp        PtpContainer, PtpUsbTransport(UsbDeviceConnection), PtpSession (open/close/get/setProp, deviceInfo)
:fuji       FujiProps (codes), FujiEnums, PresetCodec (RawProps ↔ domain Preset), PresetWriter (ordering/conditional logic)
:ofr        OfrDocument (kotlinx.serialization), OfrValidator (omission rules, ranges), OfrHasher, OfrMapper (↔ domain Preset)
:app        Compose UI, connection state machine, slot picker, import/export (share sheet .ofr.json), local library
```

---

## 7. Bonus: on-camera RAW conversion (live preview), same channel
FilmKit/rawji flow, useful for "preview this recipe on my own RAF":
`SendObjectInfo(0x900C, ObjectFormat 0xF802, name "FUP_FILE.dat") → SendObject2(0x900D, RAF bytes) → GetDevicePropValue(0xD185)` (625-byte profile; int32 fields at indices 4 ExpBias, 6 DR%, 7 DRP, 8 FilmSim, 9 Grain, 10 CC, 11 SmoothSkin, 12 WB, 13/14 WB shift, 15 Kelvin, 16/17 HL/SH ×10, 18 Color, 19 Sharp, 20 NR, 25 CCFxBlue, 27 Clarity) → patch → `SetDevicePropValue(0xD185)` → `SetDevicePropValue(0xD183 = 0)` to start → poll `GetObjectHandles(0xFFFFFFFF,0,0)` → `GetObject` (JPEG) → `DeleteObject`.

---

## 8. What to verify on real hardware first
1. Your body advertises `0xD18C..0xD1A5` in `GetDeviceInfo` while in USB RAW CONV./BACKUP RESTORE mode.
2. Slot cycling via D18C + name read D18D round-trips.
3. Write a full preset with the §3.2 ordering; read back; check on camera LCD.
4. Capture X RAW Studio with DRP=Auto/Weak/Strong, DR-Auto, WB white-priority, Custom WB to fill the unknowns (usbmon on Linux or USBPcap on Windows; filter `usb.transfer_type == 0x02`).

---

## 9. Probe results — X-S20 + Pixel 7 Pro (2026-08-19)

Tool: `probe/` (Flutter + Kotlin USB bridge, `fuji-probe.apk`). Camera in USB RAW CONV./BACKUP RESTORE, POWER SUPPLY OFF/COMM ON.

- Enumerates as `04cb:02f7`, interface 0 class 6/1/1, bulk IN 0x81 / OUT 0x01, maxPacket 512. Android permission dialog → granted → `claimInterface(force)` OK.
- `OpenSession(1)` OK first try. `GetDeviceInfo`: FUJIFILM X-S20 fw 3.30, vendor-ext id **0x6**, 20 ops (incl. 0x1015/0x1016, 0x900C/0x900D, 0x901D, 0x100C/0x100D), 59 props:
  `5005 5015 D001 D007 D008 D00A D00B D00C D017 D018 D01C D023 D029 D02E D030 D031 D032 D104 D16E D17B D183 D184 D185 D186 D187 D18C–D197 D199–D1A5 D208 D20B D212 D21C D320 D321 D34D D36A D36B` (no D198).
- Slot cycling D18C 1–4 OK, 5–7 rejected. Names empty. Per-slot values decode with the FilmKit table (DR 0xFFFF = Auto, grain 3/5, tones ×10, NR 0x8000/0x2000, WB shifts).
- **Write test:** `Set D18C=1`, `Set D192=12` → OK, read-back 12, and the **camera LCD shows C1 = Acros — after a mode-dial change** (no power cycle needed). The PTP write updates the *stored* slot; the body keeps running from an in-memory copy of the dial-selected slot until the dial is moved. **App rule:** after writing, prompt "turn the mode dial off Cx and back"; prefer writing to a slot the dial is not on (also avoids AUTO UPDATE CUSTOM SETTING writing the live copy back over it).
- Conclusion: the preset protocol works on X-S20 from Android; a third-party app failing to apply is an app bug, not a platform limitation.

**Plan 1 end-to-end OFR write (2026-08-19, Kata app via `fuji_ptp` plugin + `CameraService`):** the OFR README "Kodachrome 64" recipe (hash `ac98f459…c176`) mapped with `OfrMapper`, written to **C3** with the X RAW Studio order: `write C3 ok=true written=21 skipped=0` (21 props: D18D name + 20 values incl. passthrough D18E/D18F/D191/D1A3/D1A4/D1A5 copied from the slot; D198 absent on X-S20, D19C/D193/D194 omitted by value rules). Read-back verification passed for all 21.

Remaining unknowns: D-Range Priority (D191?), WB white-priority / Custom WB values, DR-Auto write, whether there is a PTP prop that reports the dial-selected slot (so the app can warn), and exact `AUTO UPDATE CUSTOM SETTING` interaction.

## Sources
- FilmKit (protocol, property table, write logic): https://github.com/eggricesoy/filmkit — `QUICK_REFERENCE.md`, `src/ptp/constants.ts`, `src/profile/preset-translate.ts`, `src/ptp/session.ts`, `src/ptp/transport.ts`
- Open Fuji Recipe spec: https://github.com/gosku/open-fuji-recipe (PR #1: https://github.com/gosku/open-fuji-recipe/pull/1)
- libgphoto2 Fuji definitions (`ptp.h`, `config.c` WB/film-sim tables, `library.c` USB IDs): https://github.com/gphoto/libgphoto2
- rawji (RAW conversion protocol origin): https://github.com/pinpox/rawji · fudge/camlib: https://github.com/petabyt/fudge
- Fujifilm manuals — X-T5 USB to smartphone: https://fujifilm-dsc.com/en/manual/x-t5/connections/usage_usb/ ; RAW processing / connection mode: https://fujifilm-dsc.com/en/manual/x-t5/connections/raw/
- X RAW Studio guide (USB RAW CONV./BACKUP RESTORE mode): https://www.fujifilm-x.com/global/stories/fujifilm-x-raw-studio-features-users-guide/
- FujiStyle Android USB sync guide (camera modes, OTG, M-mode caveat): https://www.fujistyleapp.com/blog/fujistyle-android-usb-recipe-sync-guide-basic-apply-recipes-tutorials-and-troubleshooting/
- Fuji Recipes app (Android USB-C write, supported bodies): https://fujirecipes.co/
- Android PTP/USB references: https://github.com/michaelzoech/remoteyourcam-usb · https://github.com/laheller/ptplibrary · https://github.com/terencehonles/Android_USB_PTP_Lib · https://developer.android.com/reference/kotlin/android/hardware/usb/UsbDeviceConnection
