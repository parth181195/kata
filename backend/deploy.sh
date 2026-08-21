#!/usr/bin/env bash
# Build locally, ship to the VM, migrate, reload pm2. Requires ssh access to $KATA_HOST.
set -euo pipefail
HOST=${KATA_HOST:?set KATA_HOST=user@host (the VM the API runs on)}
DIR=/opt/kata/api
cd "$(dirname "$0")"

npm ci
npm run build
npx prisma generate >/dev/null

rsync -az --delete \
  --exclude node_modules --exclude .env --exclude /seed \
  dist prisma package.json package-lock.json ecosystem.config.js "$HOST:$DIR/"

ssh "$HOST" "source ~/.nvm/nvm.sh >/dev/null && cd $DIR \
  && npm ci --omit=dev --no-audit --no-fund \
  && npx prisma migrate deploy \
  && (pm2 reload kata-api --update-env || pm2 start ecosystem.config.js) \
  && pm2 save"

for i in 1 2 3 4 5 6; do sleep 3; curl -fsS https://api.kata.parthjansari.dev/health && echo && exit 0; done
echo 'health check failed' >&2; exit 1
