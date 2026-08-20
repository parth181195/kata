#!/usr/bin/env bash
# Build an AppImage from an existing Linux release bundle — one file that runs anywhere,
# for distros that aren't Debian-based.
#
#   APPIMAGETOOL=/path/to/appimagetool app/packaging/linux/build-appimage.sh [--out <dir>]
#
# Note: an AppImage cannot install the udev rule (it never installs anything), so USB writing
# needs the one-time rule from the README. The .deb does that for you.
set -euo pipefail
cd "$(dirname "$0")/../.."                     # → app/
OUT="$(pwd)/build/packages"
while [ $# -gt 0 ]; do case "$1" in --out) OUT="$2"; shift 2;; *) echo "unknown arg $1" >&2; exit 2;; esac; done
TOOL=${APPIMAGETOOL:-appimagetool}
command -v "$TOOL" >/dev/null 2>&1 || [ -x "$TOOL" ] || { echo "appimagetool not found — set APPIMAGETOOL=<path>" >&2; exit 1; }

BUNDLE=build/linux/x64/release/bundle
[ -x "$BUNDLE/kata" ] || { echo "no release bundle — run: fvm flutter build linux --release" >&2; exit 1; }
VERSION=$(grep -E '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)
APPDIR=$(mktemp -d)/Kata.AppDir
trap 'rm -rf "$(dirname "$APPDIR")"' EXIT

install -d "$APPDIR/usr/bin" "$APPDIR/usr/share/icons/hicolor/512x512/apps" "$APPDIR/usr/share/applications"
cp -r "$BUNDLE"/* "$APPDIR/usr/bin/"

ICON=android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
cp "$ICON" "$APPDIR/usr/share/icons/hicolor/512x512/apps/kata.png"
cp "$ICON" "$APPDIR/kata.png"

cat > "$APPDIR/kata.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Kata
GenericName=Film recipe writer
Comment=Write Fujifilm film simulation recipes into your camera's custom slots
Exec=kata
Icon=kata
Terminal=false
Categories=Graphics;Photography;
DESKTOP
cp "$APPDIR/kata.desktop" "$APPDIR/usr/share/applications/kata.desktop"

cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
HERE=$(dirname "$(readlink -f "$0")")
exec "$HERE/usr/bin/kata" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

mkdir -p "$OUT"
ARCH=x86_64 "$TOOL" "$APPDIR" "$OUT/Kata-$VERSION-x86_64.AppImage" >/dev/null 2>&1
echo "$OUT/Kata-$VERSION-x86_64.AppImage"
