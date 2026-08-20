# Kata Desktop — dev notes

## USB (Linux)
libusb-1.0 is loaded at runtime (`libusb-1.0.so.0`, package `libusb-1.0-0`). Without a udev rule the camera is only accessible as root. Install once:

```bash
sudo tee /etc/udev/rules.d/71-fujifilm.rules >/dev/null <<'RULE'
SUBSYSTEM=="usb", ATTR{idVendor}=="04cb", MODE="0666", TAG+="uaccess"
RULE
sudo udevadm control --reload && sudo udevadm trigger
```
Replug the camera afterwards. macOS needs nothing; Windows needs the camera interface bound to WinUSB (Zadig) — deferred.

## Sign-in
Desktop uses a Google OAuth client of type **Desktop app** with the loopback flow; the API accepts its ID tokens via `GOOGLE_EXTRA_CLIENT_IDS` in `/opt/kata/api/.env`. Until the client exists, desktop builds show the sign-in wall.

## Transport
`LibusbHost` (packages/fuji_ptp) implements the same `UsbHost`/`UsbLink` as the Android bridge; all libusb calls run on a worker isolate; hotplug via 2s polling. Device names are `bus:addr`.
