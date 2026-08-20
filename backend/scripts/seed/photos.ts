/**
 * Attach crawled sample photos to library recipes.
 *
 *   seed photos <library.json|crawler manifest.json> --root <downloads dir> [--per 3] [--only <recipeId>] [--dry]
 *     --per N tops up: a recipe already holding fewer than N photos gets the missing ones
 *     appended, so raising the cap backfills instead of starting over.
 *     → resizes (1600 main + 400 thumb, same as the API) and uploads to Bunny; writes seed/photos-report.json {recipeId: [urls]} (resumable)
 *   seed photos-apply <api base> <admin access token> [--report seed/photos-report.json]
 *     → PATCH /admin/recipes/:id {imageUrls} for every recipe in the report
 *
 * Needs BUNNY_STORAGE_ZONE / BUNNY_STORAGE_KEY / BUNNY_STORAGE_HOST / BUNNY_PULL_ZONE_HOST in the environment.
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import sharp from 'sharp';
import { HttpBunnyClient } from '../../src/images/http-bunny.client';

interface LibraryPhoto { index: number; file?: string; width?: number; height?: number; bytes?: number }
interface LibraryRecipe { id: string; name: string; image_urls?: string[]; photos?: LibraryPhoto[] }

/** The crawler writes {posts: [{recipe_id, title, photos}]}; the library file uses {recipes: [...]}. */
function readRecipes(file: string): LibraryRecipe[] {
  const doc = JSON.parse(readFileSync(file, 'utf8')) as {
    recipes?: LibraryRecipe[];
    posts?: { recipe_id: string; title: string; photos?: LibraryPhoto[] }[];
  };
  if (doc.recipes) return doc.recipes;
  return (doc.posts ?? []).map((p) => ({ id: p.recipe_id, name: p.title, photos: p.photos }));
}
type PhotoReport = Record<string, string[]>;

const REPORT = join('seed', 'photos-report.json');
const loadReport = (p: string): PhotoReport => (existsSync(p) ? (JSON.parse(readFileSync(p, 'utf8')) as PhotoReport) : {});
const uid = () => `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;

export async function cmdPhotos(libraryFile: string, flags: string[]): Promise<void> {
  const root = flagVal(flags, '--root');
  if (!root) throw new Error('--root <downloads dir> is required');
  const per = Number(flagVal(flags, '--per') ?? 3);
  const only = flagVal(flags, '--only');
  const dry = flags.includes('--dry');
  const recipes = readRecipes(libraryFile);
  mkdirSync('seed', { recursive: true });
  const report = loadReport(REPORT);
  const bunny = new HttpBunnyClient();
  let done = 0, skipped = 0, failed = 0, uploaded = 0;
  for (const r of recipes) {
    if (only && r.id !== only) continue;
    const already = report[r.id]?.length ?? 0;
    if (already >= per) { skipped++; continue; }
    const usable = (r.photos ?? [])
      .filter((p) => p.file && (p.width ?? 0) >= 600)
      .sort((a, b) => a.index - b.index)
      .slice(0, per);
    // top-up: the first `already` are on Bunny from an earlier run, upload only what's new
    const photos = usable.slice(already);
    if (!photos.length) { skipped++; continue; }
    const urls: string[] = [...(report[r.id] ?? [])];
    for (const p of photos) {
      const path = join(root, p.file!);
      if (!existsSync(path)) { console.error(`  missing ${path}`); continue; }
      try {
        const src = sharp(readFileSync(path)).rotate();
        const main = await src.clone().resize({ width: 1600, height: 1600, fit: 'inside', withoutEnlargement: true }).jpeg({ quality: 82, mozjpeg: true }).toBuffer();
        const thumb = await src.clone().resize({ width: 400, height: 400, fit: 'inside', withoutEnlargement: true }).jpeg({ quality: 78, mozjpeg: true }).toBuffer();
        const id = uid();
        if (dry) {
          urls.push(`dry://recipes/${r.id}/${id}.jpg (${(main.length / 1024).toFixed(0)}k / ${(thumb.length / 1024).toFixed(0)}k)`);
        } else {
          const url = await bunny.put(`recipes/${r.id}/${id}.jpg`, main, 'image/jpeg');
          await bunny.put(`recipes/${r.id}/${id}_t.jpg`, thumb, 'image/jpeg');
          urls.push(url);
        }
        uploaded++;
      } catch (e) {
        console.error(`  ${r.name}: ${(e as Error).message}`);
        failed++;
      }
    }
    if (urls.length > already) {
      report[r.id] = urls;
      if (!dry) writeFileSync(REPORT, JSON.stringify(report, null, 1));
      done++;
      console.log(`✓ ${r.name} ${already ? `${already}→${urls.length}` : `+${urls.length}`}${dry ? ' (dry)' : ''}`);
    }
  }
  console.log(`\nrecipes ${done} · skipped ${skipped} · photos ${uploaded} · failed ${failed}${dry ? ' · DRY RUN (report not written)' : ` → ${REPORT}`}`);
}

export async function cmdPhotosApply(apiBase: string, token: string, flags: string[]): Promise<void> {
  const report = loadReport(flagVal(flags, '--report') ?? REPORT);
  let ok = 0, failed = 0;
  const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
  for (const [id, imageUrls] of Object.entries(report)) {
    for (let attempt = 0; attempt < 4; attempt++) {
      const res = await fetch(`${apiBase.replace(/\/$/, '')}/admin/recipes/${id}`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ imageUrls }),
      });
      if (res.ok) { ok++; break; }
      if (res.status === 429) { await sleep(15_000 * (attempt + 1)); continue; } // API throttles at 60/min
      failed++; console.error(`✗ ${id}: ${res.status} ${(await res.text()).slice(0, 120)}`); break;
    }
    await sleep(1100); // stay under the throttle
  }
  console.log(`applied ${ok} · failed ${failed}`);
}

function flagVal(flags: string[], name: string): string | undefined {
  const i = flags.indexOf(name);
  return i >= 0 ? flags[i + 1] : undefined;
}
