# fuji_ptp

PTP-over-USB client for Fujifilm X / GFX cameras, written in Dart with a thin Android USB-host bridge.

- `PtpTransport` — ISO 15740 containers over bulk endpoints (`UsbLink` abstraction; Android implementation via `UsbBridge`).
- `DeviceInfo` — parsed `GetDeviceInfo`.
- `FujiCamera` — Custom Settings (C1–C7) preset protocol: capabilities (slot count, supported props), `readSlot`, `readAllSlots`, `writePreset` with X RAW Studio write order + read-back verification, stale-session recovery.
- `CameraPreset`, `PresetCodec`, `PresetWriter` — pure value types/encoders you can unit-test without hardware.

Camera must be in `CONNECTION SETTING → CONNECTION MODE → USB RAW CONV./BACKUP RESTORE`.
Protocol notes: see the Kata repo `docs/fuji-usb-research.md`. Verified on X-S20 (fw 3.30) and, via FilmKit's work, X100VI.

MIT.
