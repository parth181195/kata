# Kata API — operations

Host: a GCP VM (set `KATA_HOST=user@host` for the deploy scripts) (Ubuntu 25.04, Node 24 via nvm, pm2 6, nginx + certbot, Postgres 17). App dir `/opt/kata/api`, pm2 app `kata-api`, port `127.0.0.1:5090`, public **`https://api.kata.parthjansari.dev`**; landing page `https://kata.parthjansari.dev` (static, `/opt/kata/web`); admin SPA `https://admin.kata.parthjansari.dev` (`/opt/kata/admin`).

## One-time setup (sudo/root on the VM)
1. **DNS:** A records `kata`, `api.kata`, `admin.kata` → the VM's IP (in the zone that `ns-cloud-e1..e4.googledomains.com` serve).
2. **Postgres role + db**
   ```bash
   sudo -u postgres psql -c "create role kata with login password 'CHANGE_ME';"
   sudo -u postgres psql -c "create database kata owner kata;"
   sudo -u postgres psql -d kata -c "create extension if not exists pg_trgm;"
   ```
3. **Env file** `/opt/kata/api/.env` (never committed):
   ```
   PORT=5090
   NODE_ENV=production
   DATABASE_URL=postgresql://kata:CHANGE_ME@127.0.0.1:5432/kata
   JWT_SECRET=<openssl rand -base64 48>
   GOOGLE_WEB_CLIENT_ID=<web client id>.apps.googleusercontent.com
   BUNNY_STORAGE_ZONE=onfrm                      # shared with onframe; Kata writes under BUNNY_PREFIX=kata/
   BUNNY_STORAGE_KEY=<storage access key>
   BUNNY_STORAGE_HOST=storage.bunnycdn.com      # or sg.storage.bunnycdn.com etc. (zone region)
   BUNNY_PULL_ZONE_HOST=<pullzone>.b-cdn.net
   ```
4. **nginx + TLS**
   ```bash
   sudo cp /opt/kata/api/deploy/nginx-kata.conf /etc/nginx/sites-available/kata   # or scp from repo: backend/deploy/nginx-kata.conf
   sudo ln -s /etc/nginx/sites-available/kata /etc/nginx/sites-enabled/kata
   sudo nginx -t && sudo systemctl reload nginx
   sudo certbot --nginx -d kata.parthjansari.dev -d api.kata.parthjansari.dev -d admin.kata.parthjansari.dev
   ```
5. `mkdir -p /opt/kata/web /opt/kata/admin` (placeholder `index.html` until the landing/admin ship).
6. First deploy from the dev machine: `backend/deploy.sh` (builds, rsyncs `dist/ prisma/ package*.json ecosystem.config.js`, `npm ci --omit=dev`, `prisma migrate deploy`, pm2 start/reload, curls `/health`).
7. Promote yourself to admin after first sign-in: `sudo -u postgres psql -d kata -c "update users set role='admin' where email='you@gmail.com';"`

## Day 2
- Deploy: `backend/deploy.sh` (migrations auto-apply).
- Logs: `pm2 logs kata-api`, `pm2 status`.
- Seed recipes: copy `urls.txt` to `/opt/kata/api/`, then `cd /opt/kata/api && source ~/.nvm/nvm.sh && node dist/scripts/seed/index.js import urls.txt --images` (report in `seed/report.json`).
- Rotate JWT secret: edit `.env`, `pm2 reload kata-api --update-env` (all sessions invalidate; refresh tokens stay valid until used).
- DB backup: `sudo -u postgres pg_dump -Fc kata > /var/www/backups/kata-$(date +%F).dump`.

## Local dev
`backend/.env` points at `postgresql://kata:kata@localhost:5432/kata`; tests use `kata_test`. `npm run start:dev`, `npm test`, `npm run test:e2e`, `npm run prisma:migrate` (creates a migration file; edit if raw SQL is needed; `prisma migrate dev` will always report the generated `search` column as drift — that is expected, do not accept its auto-migration).

## Landing page + APK (`kata.parthjansari.dev`)
- Static files in `web/landing/`, deployed with `web/deploy.sh` (rsync → `/opt/kata/web`). Add `--apk app/build/app/outputs/flutter-apk/app-release.apk` to publish a build as `/kata.apk` (kept under `downloads/kata-<version>.apk`; version from `app/pubspec.yaml`).
- Build the APK with the Google Web client id: `fvm flutter build apk --release --target-platform android-arm64 --dart-define-from-file=secrets/android.json` (see `app/secrets/README.md`; backups of the filled-in files: `/root/keys/app-secrets/` on the VM).
- nginx: `location ~ \.apk$` sets the Android package MIME type + `Content-Disposition: attachment` (in `backend/deploy/nginx-kata.conf`; the live file under `/etc/nginx/sites-enabled/kata` also carries certbot's TLS blocks — edit in place, don't overwrite).

## Admin console (`admin.kata.parthjansari.dev`)
- Source `web/admin/` (Vite/React). Deploy: `web/deploy.sh --admin [--no-landing]` (builds with `npm ci && npm run build`, rsyncs `dist/` → `/opt/kata/admin`). `.env.production` holds the public Web client id + API base.
- Promote an account: first sign in once from the app or the admin page (creates the user), then Creators → "Make admin", or SQL: `update users set role='admin' where email='…'`.
- Google OAuth Web client must list `https://admin.kata.parthjansari.dev` (and `http://localhost:5173` for dev) under Authorized JavaScript origins; no redirect URIs needed (GIS ID-token popup).
