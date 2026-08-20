#!/usr/bin/env bash
# Build a .deb from an existing Linux release bundle.
#
#   app/packaging/linux/build-deb.sh [--out <dir>]
#
# Produces kata_<version>_amd64.deb. Unlike the tarball this installs the udev rule for you,
# so USB writing works after a replug with no terminal step, and it puts Kata in the launcher.
set -euo pipefail
cd "$(dirname "$0")/../.."                     # → app/
OUT="$(pwd)/build/packages"
while [ $# -gt 0 ]; do case "$1" in --out) OUT="$2"; shift 2;; *) echo "unknown arg $1" >&2; exit 2;; esac; done

BUNDLE=build/linux/x64/release/bundle
[ -x "$BUNDLE/kata" ] || { echo "no release bundle — run: fvm flutter build linux --release" >&2; exit 1; }
VERSION=$(grep -E '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)
ARCH=amd64
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

# ---- payload: the app lives in /opt, with a launcher symlink on PATH
install -d "$STAGE/opt/kata" "$STAGE/usr/bin" "$STAGE/usr/share/applications" \
           "$STAGE/usr/share/icons/hicolor/512x512/apps" "$STAGE/usr/lib/udev/rules.d" \
           "$STAGE/usr/share/doc/kata" "$STAGE/DEBIAN"
cp -r "$BUNDLE"/* "$STAGE/opt/kata/"
ln -s /opt/kata/kata "$STAGE/usr/bin/kata"

ICON=android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
[ -f "$ICON" ] && cp "$ICON" "$STAGE/usr/share/icons/hicolor/512x512/apps/kata.png"

cat > "$STAGE/usr/share/applications/kata.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Kata
GenericName=Film recipe writer
Comment=Write Fujifilm film simulation recipes into your camera's custom slots
Exec=/opt/kata/kata
Icon=kata
Terminal=false
Categories=Graphics;Photography;
Keywords=fujifilm;film simulation;recipe;camera;
DESKTOP

# ---- the step the tarball asks people to do by hand
cat > "$STAGE/usr/lib/udev/rules.d/70-kata-fuji.rules" <<'UDEV'
# Kata: let the desktop user talk to a Fujifilm camera, and stop the photo daemon claiming it
SUBSYSTEM=="usb", ATTR{idVendor}=="04cb", MODE="0666", TAG+="uaccess", ENV{ID_GPHOTO2}="", ENV{GPHOTO2_DRIVER}=""
UDEV

INSTALLED_KB=$(du -sk "$STAGE/opt" | cut -f1)
cat > "$STAGE/DEBIAN/control" <<CONTROL
Package: kata
Version: $VERSION
Section: graphics
Priority: optional
Architecture: $ARCH
Maintainer: Parth Jansari <parthrock181195@gmail.com>
Installed-Size: $INSTALLED_KB
Depends: libgtk-3-0 | libgtk-3-0t64, libglib2.0-0 | libglib2.0-0t64, libusb-1.0-0, libsecret-1-0, libjsoncpp25 | libjsoncpp26 | libjsoncpp1, libsqlite3-0, libstdc++6, libc6
Recommends: xdg-utils
Homepage: https://kata.parthjansari.dev
Description: Write Fujifilm film recipes into your camera over USB
 Kata keeps every film-simulation recipe you like in one library and writes it
 straight into your camera's custom slots (C1-C7) over a USB cable, instead of
 typing twenty-two menu items by hand.
 .
 Nothing is sent to the camera until you approve a field-by-field diff, and every
 slot is backed up before a write, so a bad write can always be undone.
CONTROL

cat > "$STAGE/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
# apply the rule now so the camera works without a reboot (a replug is still needed)
if [ -x /sbin/udevadm ] || command -v udevadm >/dev/null 2>&1; then
  udevadm control --reload-rules >/dev/null 2>&1 || true
  udevadm trigger --subsystem-match=usb >/dev/null 2>&1 || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database -q || true; fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then gtk-update-icon-cache -q /usr/share/icons/hicolor || true; fi
echo "Kata installed. Set the camera to USB RAW CONV./BACKUP RESTORE, then plug it in."
POSTINST

cat > "$STAGE/DEBIAN/postrm" <<'POSTRM'
#!/bin/sh
set -e
if [ "$1" = purge ]; then
  if command -v udevadm >/dev/null 2>&1; then udevadm control --reload-rules >/dev/null 2>&1 || true; fi
fi
POSTRM
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

cp ../README.md "$STAGE/usr/share/doc/kata/README.md" 2>/dev/null || true

mkdir -p "$OUT"
DEB="$OUT/kata_${VERSION}_${ARCH}.deb"
fakeroot dpkg-deb --build --root-owner-group "$STAGE" "$DEB" >/dev/null
echo "$DEB"
dpkg-deb --info "$DEB" | sed -n '1,12p'
