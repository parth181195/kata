#!/usr/bin/env bash
# Build locally, ship to the VM, migrate, reload pm2. Requires ssh access to root@YOUR.VM.IP.
set -euo pipefail
HOST=${KATA_HOST:-root@YOUR.VM.IP}
DIR=/opt/kata/api
cd "$(dirname "$0")"

npm ci
npm run build
npx prisma generate >/dev/null

rsync -az --delete \
  --exclude node_modules --exclude .env --exclude seed \
  dist prisma package.json package-lock.json ecosystem.config.js "$HOST:$DIR/"

ssh "$HOST" "source ~/.nvm/nvm.sh >/dev/null && cd $DIR \
  && npm ci --omit=dev --no-audit --no-fund \
  && npx prisma migrate deploy \
  && (pm2 reload kata-api --update-env || pm2 start ecosystem.config.js) \
  && pm2 save"

sleep 2
curl -fsS https://kata.parthjansari.dev/api/health && echo
