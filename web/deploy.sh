#!/usr/bin/env bash
# Ship the landing page (and optionally an APK) to the VM. Usage: web/deploy.sh [--apk app/build/app/outputs/flutter-apk/app-release.apk]
set -euo pipefail
HOST=${KATA_HOST:-root@YOUR.VM.IP}
DIR=/opt/kata/web
cd "$(dirname "$0")"
APK=""
while [ $# -gt 0 ]; do case "$1" in --apk) APK="$2"; shift 2;; *) echo "unknown arg $1" >&2; exit 2;; esac; done

rsync -az --delete --exclude downloads --exclude kata.apk landing/ "$HOST:$DIR/"

if [ -n "$APK" ]; then
  VER=$(grep -E '^version:' ../app/pubspec.yaml | awk '{print $2}' | cut -d+ -f1)
  ssh "$HOST" "mkdir -p $DIR/downloads"
  rsync -az "$APK" "$HOST:$DIR/downloads/kata-$VER.apk"
  ssh "$HOST" "ln -sf $DIR/downloads/kata-$VER.apk $DIR/kata.apk"
  echo "published kata-$VER.apk → /kata.apk"
fi

curl -fsS -o /dev/null -w 'landing %{http_code}\n' https://kata.parthjansari.dev/
[ -z "$APK" ] || curl -fsSI https://kata.parthjansari.dev/kata.apk | grep -iE '^(HTTP|content-type|content-length)'
