# web/

Static sites served by nginx on the VM (see `backend/deploy/nginx-kata.conf`).

- `landing/` → `https://kata.parthjansari.dev/` (`/opt/kata/web`). Plain HTML + CSS, no build step; fonts from Google Fonts; images are dot-grid placeholders until we have permitted photos. `privacy.html` is the policy linked from the app and the Google OAuth consent screen. `qr-install.svg` encodes `https://kata.parthjansari.dev/kata.apk`.
- `deploy.sh` — `./web/deploy.sh [--apk path/to/app-release.apk]` rsyncs `landing/` and optionally publishes the APK as `/kata.apk` (+ `downloads/kata-<version>.apk`).

Admin SPA (Plan 5) will live in `web/admin/` → `admin.kata.parthjansari.dev`.
