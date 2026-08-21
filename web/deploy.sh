#!/usr/bin/env bash
# Ship the landing page (and optionally an APK, the Linux desktop tarball, and/or the admin
# SPA) to the VM. Build artefacts live in downloads/ and are linked from stable paths.
# Usage: web/deploy.sh [--apk <path>] [--desktop <path.tar.gz>] [--deb <path.deb>]
#                      [--appimage <path.AppImage>] [--admin] [--lib] [--no-landing]
# Paths must be absolute: this script cd's to its own directory.
set -euo pipefail
HOST=${KATA_HOST:?set KATA_HOST=user@host (the VM this site deploys to)}
DIR=/opt/kata/web
ADMIN_DIR=/opt/kata/admin
cd "$(dirname "$0")"
APK=""; DESKTOP=""; DEB=""; APPIMAGE=""; ADMIN=0; LIB=0; LANDING=1
while [ $# -gt 0 ]; do case "$1" in
  --apk) APK="$2"; shift 2;;
  --desktop) DESKTOP="$2"; shift 2;;
  --deb) DEB="$2"; shift 2;;
  --appimage) APPIMAGE="$2"; shift 2;;
  --admin) ADMIN=1; shift;;
  --lib) LIB=1; shift;;
  --no-landing) LANDING=0; shift;;
  *) echo "unknown arg $1" >&2; exit 2;;
esac; done

if [ "$LANDING" = 1 ]; then
  # keep the published artefacts and their stable links: --delete would take them otherwise
  rsync -az --delete --exclude downloads --exclude kata.apk --exclude kata-linux.tar.gz \
    --exclude kata.deb --exclude kata.AppImage --exclude /library landing/ "$HOST:$DIR/"
fi

if [ "$LIB" = 1 ]; then
  (cd lib && npm ci --no-audit --no-fund >/dev/null && npm run build >/dev/null)
  ssh "$HOST" "mkdir -p $DIR/library"
  rsync -az --delete lib/dist/ "$HOST:$DIR/library/"
  curl -fsS -o /dev/null -w 'weblib %{http_code}\n' https://kata.parthjansari.dev/library/
fi

if [ "$ADMIN" = 1 ]; then
  (cd admin && npm ci --no-audit --no-fund >/dev/null && npm run build >/dev/null)
  ssh "$HOST" "mkdir -p $ADMIN_DIR"
  rsync -az --delete admin/dist/ "$HOST:$ADMIN_DIR/"
  curl -fsS -o /dev/null -w 'admin %{http_code}\n' https://admin.kata.parthjansari.dev/
fi

if [ -n "$DESKTOP" ]; then
  VER=$(grep -E '^version:' ../app/pubspec.yaml | awk '{print $2}' | cut -d+ -f1)
  ssh "$HOST" "mkdir -p $DIR/downloads"
  rsync -az "$DESKTOP" "$HOST:$DIR/downloads/kata-$VER-linux-x64.tar.gz"
  ssh "$HOST" "ln -sf $DIR/downloads/kata-$VER-linux-x64.tar.gz $DIR/kata-linux.tar.gz"
  echo "published kata-$VER-linux-x64.tar.gz → /kata-linux.tar.gz"
fi

if [ -n "$DEB" ]; then
  VER=$(grep -E '^version:' ../app/pubspec.yaml | awk '{print $2}' | cut -d+ -f1)
  ssh "$HOST" "mkdir -p $DIR/downloads"
  rsync -az "$DEB" "$HOST:$DIR/downloads/kata_${VER}_amd64.deb"
  ssh "$HOST" "ln -sf $DIR/downloads/kata_${VER}_amd64.deb $DIR/kata.deb"
  echo "published kata_${VER}_amd64.deb → /kata.deb"
fi

if [ -n "$APPIMAGE" ]; then
  VER=$(grep -E '^version:' ../app/pubspec.yaml | awk '{print $2}' | cut -d+ -f1)
  ssh "$HOST" "mkdir -p $DIR/downloads"
  rsync -az "$APPIMAGE" "$HOST:$DIR/downloads/Kata-${VER}-x86_64.AppImage"
  ssh "$HOST" "ln -sf $DIR/downloads/Kata-${VER}-x86_64.AppImage $DIR/kata.AppImage"
  echo "published Kata-${VER}-x86_64.AppImage → /kata.AppImage"
fi

if [ -n "$APK" ]; then
  VER=$(grep -E '^version:' ../app/pubspec.yaml | awk '{print $2}' | cut -d+ -f1)
  ssh "$HOST" "mkdir -p $DIR/downloads"
  rsync -az "$APK" "$HOST:$DIR/downloads/kata-$VER.apk"
  ssh "$HOST" "ln -sf $DIR/downloads/kata-$VER.apk $DIR/kata.apk"
  echo "published kata-$VER.apk → /kata.apk"
fi

[ "$LANDING" = 0 ] || curl -fsS -o /dev/null -w 'landing %{http_code}\n' https://kata.parthjansari.dev/
[ -z "$APK" ] || curl -fsSI https://kata.parthjansari.dev/kata.apk | grep -iE '^(HTTP|content-type|content-length)'
[ -z "$DESKTOP" ] || curl -fsSI https://kata.parthjansari.dev/kata-linux.tar.gz | grep -iE '^(HTTP|content-length)'
[ -z "$DEB" ] || curl -fsSI https://kata.parthjansari.dev/kata.deb | grep -iE '^(HTTP|content-length)'
[ -z "$APPIMAGE" ] || curl -fsSI https://kata.parthjansari.dev/kata.AppImage | grep -iE '^(HTTP|content-length)'
