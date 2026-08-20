# Fujifilm over Wi-Fi (PTP/IP) — what we know, and the one open question

**Status (2026-08-20):** transport implemented and unit-tested; the decisive live probe has
**not run yet** — the camera has not been put into wireless mode.

## Why bother

Everything Kata does needs a cable today. If a body exposes the Custom Settings protocol over
Wi-Fi, recipes can be written with no cable at all — which matters most on the phone, where
plugging in a USB-C camera is the whole friction.

## The protocol

Fujifilm speaks a PTP/IP variant (ISO 15740 Annex) over TCP:

| Port  | Channel        | Do we use it |
|-------|----------------|--------------|
| 55740 | Command / data | yes — the preset protocol is all command/data |
| 55741 | Events         | no |
| 55742 | Live view      | no |

Framing: `uint32 length` (little-endian, includes the header) + `uint32 packet type` + payload.
Handshake is `InitCommandRequest` (16-byte client GUID, UTF-16LE null-terminated client name,
4-byte protocol version `0x00010000`) → `InitCommandAck` (session id + the camera's own
GUID/name) — or `InitFail` if the body refuses. After that it is ordinary PTP: `OpenSession`,
`GetDeviceInfo`, `GetDevicePropValue`, `SetDevicePropValue`, with the data phase carried in
`StartData` / `Data` / `EndData` packets instead of USB bulk transfers.

Community projects read Fuji **vendor** properties over this link — including `0xD212`, the
exact property Kata's USB heartbeat polls. So vendor props are reachable in principle.

## Implementation

- `packages/fuji_ptp/lib/src/ptp/ptpip.dart` — `PtpIpTransport` (framing, handshake,
  transactions, data phases) plus `scanForCameras(subnet)` which probes port 55740 across a /24.
- `PtpSession` (in `transport.dart`) is the shared interface: `PtpTransport` (USB bulk) and
  `PtpIpTransport` (TCP) both implement it, and `FujiCamera` takes a `PtpSession`. **The entire
  Fuji layer — slot select, preset codec, writer, verify, diff, backups — is transport-agnostic
  already.** Wireless support is a transport plus UI, not a rewrite.
- `test/ptpip_test.dart` — five tests against a scripted fake camera: handshake bytes, data-in
  reassembly across split frames, data-out framing, refusal handling, transaction numbering.

## The open question

**Does a body still expose `0xD18C` (custom-slot select) and `0xD18D–0xD1A5` (the preset
fields) while in wireless mode?** Fuji gates capabilities by connection mode, and the wireless
modes are aimed at tethered shooting and image transfer. Nobody has documented the preset
properties over Wi-Fi either way.

This is a yes/no, and it is cheap to answer:

```bash
cd packages/fuji_ptp
KATA_LIVE=1 KATA_SUBNET=192.168.0 fvm flutter test test/wifi_probe_test.dart   # scan
KATA_LIVE=1 KATA_CAM_IP=192.168.0.42 fvm flutter test test/wifi_probe_test.dart  # direct
```

The probe connects, opens a session, reads `GetDeviceInfo`, prints how many of the 26 preset
properties are present, and — if `0xD18C` is there — actually reads it, so "present" means
"answers", not merely "listed". If it is absent, the probe dumps the full property and
operation lists so we know exactly what the wireless ceiling is.

### Getting the camera onto the network (X-S20)

1. Unplug USB (or Eject in Kata) — a body in `USB RAW CONV./BACKUP RESTORE` will not do wireless.
2. `MENU → NETWORK/USB SETTING → NETWORK SETTING` → register the access point; it must be the
   same network as the machine running the probe.
3. Start a mode that raises the network stack (`PC AUTO SAVE`, tethered shooting, or connect to
   a device). The PTP/IP port only listens while such a mode is active.

### If the answer is yes

Add a `WirelessCameraHost` alongside `LibusbHost`/`UsbBridge` (discovery + connect), let
`CameraService` accept either, and the existing write/review/backup flow works unchanged.

### If the answer is no

Record the exposed command set here and stop — the cable stays required for writing, and this
transport still has value for anything read-only Fuji does allow wirelessly.
