# Kata seeder

Turns a list of recipe post URLs into validated OFR recipes in the database.

```
npm run seed -- scrape https://fujixweekly.com/2020/05/27/my-fujifilm-x100v-kodachrome-64-film-simulation-recipe/
npm run seed -- import urls.txt            # insert (skips duplicates by OFR hash)
npm run seed -- import urls.txt --images   # also pull up to 3 post images → resize → Bunny
```

`urls.txt`: one URL per line, `#` comments allowed. Output report: `seed/report.json` (`ok` / `skipped` / `failed`). Failures are never silent.

Parser: Fuji X Weekly posts (film-sim line + `Key: Value` lines, `Grain Effect: Weak, Small`, `White Balance: Daylight, +2 Red & -5 Blue` / `5800K, …`, `Sharpening`, `Noise Reduction`, `Exposure Compensation` → `x_exposure_comp`). Sensors come from the model in the title/tags (X100V → X-Trans IV, X-T5 → X-Trans V, …).

On the VM (built): `cd /opt/kata/api && node dist/scripts/seed/index.js import urls.txt --images`.

## Library dumps

The seeder writes straight to Postgres (plus a per-run `seed/report.json` of ok/skipped/failed URLs on the VM — `/opt/kata/api/seed/report.json`). Full JSON snapshots of the public library live in `backend/data/library-<date>.json` (`{exported_at, count, recipes:[{id,name,film_sim,sensors,source_url,source_attribution,reviewed,image_urls,ofr}]}`), produced with:

```bash
ssh root@<vm> 'set -a; . /opt/kata/api/.env; set +a; psql "$DATABASE_URL" -At -c "select json_build_object(... json_agg(...) ...) from recipes where hidden = false"' > backend/data/library-$(date +%F).json
```

## Photos (Fuji X Weekly crawl, permission granted 2026-08-20)

Crawler output lives outside the repo (`~/WebstormProjects/personal/fuji_x_weekly_crawler/`: `downloads/<recipe-id>/NN-*.jpg`, `manifest.json`); `backend/data/library-2026-08-19.json` carries each recipe's `photos[]` (index, file, size).

```bash
# 1. resize + upload the first 3 usable photos per recipe to Bunny (resumable; writes seed/photos-report.json)
BUNNY_STORAGE_ZONE=… BUNNY_STORAGE_KEY=… BUNNY_STORAGE_HOST=storage.bunnycdn.com BUNNY_PULL_ZONE_HOST=… \
DATABASE_URL=x JWT_SECRET=x npx ts-node -T scripts/seed/index.ts photos data/library-2026-08-19.json \
  --root ~/WebstormProjects/personal/fuji_x_weekly_crawler/downloads --per 3       # add --dry to preview
# 2. set imageUrls on the live recipes through the admin API
DATABASE_URL=x JWT_SECRET=x npx ts-node -T scripts/seed/index.ts photos-apply https://api.kata.parthjansari.dev <admin access token>
```
