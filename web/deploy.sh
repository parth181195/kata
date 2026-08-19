#!/usr/bin/env bash
# Ship the landing page (and optionally an APK and/or the admin SPA) to the VM.
# Usage: web/deploy.sh [--apk app/build/app/outputs/flutter-apk/app-release.apk] [--admin] [--no-landing]
set -euo pipefail
HOST=${KATA_HOST:-root@YOUR.VM.IP}
DIR=/opt/kata/web
ADMIN_DIR=/opt/kata/admin
cd "$(dirname "$0")"
APK=""; ADMIN=0; LANDING=1
while [ $# -gt 0 ]; do case "$1" in
  --apk) APK="$2"; shift 2;;
  --admin) ADMIN=1; shift;;
  --no-landing) LANDING=0; shift;;
  *) echo "unknown arg $1" >&2; exit 2;;
esac; done

if [ "$LANDING" = 1 ]; then
  rsync -az --delete --exclude downloads --exclude kata.apk landing/ "$HOST:$DIR/"
fi

if [ "$ADMIN" = 1 ]; then
  (cd admin && npm ci --no-audit --no-fund >/dev/null && npm run build >/dev/null)
  ssh "$HOST" "mkdir -p $ADMIN_DIR"
  rsync -az --delete admin/dist/ "$HOST:$ADMIN_DIR/"
  curl -fsS -o /dev/null -w 'admin %{http_code}\n' https://admin.kata.parthjansari.dev/
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
