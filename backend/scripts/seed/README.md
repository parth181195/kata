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
