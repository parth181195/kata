/* eslint-disable no-console */
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import sharp from 'sharp';
import { env } from '../../src/config/env';
import { HttpBunnyClient } from '../../src/images/http-bunny.client';
import { hasErrors, isMonoFilmSim, ofrHash, str, strList, validateOfr } from '../../src/ofr';
import { parseFxwPost } from './scrape-fxw';

const UA = 'Mozilla/5.0 (compatible; KataSeeder/1.0; +https://kata.parthjansari.dev)';

async function fetchHtml(url: string): Promise<string> {
  const res = await fetch(url, { headers: { 'User-Agent': UA, Accept: 'text/html' } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.text();
}

async function cmdScrape(url: string) {
  const r = parseFxwPost(await fetchHtml(url), url);
  if ('error' in r) {
    console.error(`✗ ${r.error}`);
    process.exit(2);
  }
  const issues = validateOfr(r.ofr);
  console.log(JSON.stringify({ ...r.ofr, hash: ofrHash(r.ofr) }, null, 2));
  if (issues.length) console.error('issues:', issues);
  console.error(`images: ${r.imageUrls.length}`);
}

interface Report {
  ok: { url: string; id: string; name: string; images: number }[];
  skipped: { url: string; reason: string }[];
  failed: { url: string; error: string }[];
}

async function uploadImages(bunny: HttpBunnyClient, recipeId: string, urls: string[], max: number): Promise<string[]> {
  const out: string[] = [];
  for (const u of urls.slice(0, max)) {
    try {
      const res = await fetch(u, { headers: { 'User-Agent': UA } });
      if (!res.ok) continue;
      const buf = Buffer.from(await res.arrayBuffer());
      const main = await sharp(buf).rotate().resize({ width: 1600, height: 1600, fit: 'inside', withoutEnlargement: true }).jpeg({ quality: 82 }).toBuffer();
      const id = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
      out.push(await bunny.put(`recipes/${recipeId}/${id}.jpg`, main, 'image/jpeg'));
    } catch (e) {
      console.error(`  image failed ${u}: ${(e as Error).message}`);
    }
  }
  return out;
}

async function cmdImport(file: string, withImages: boolean) {
  const prisma = new PrismaClient();
  const bunny = new HttpBunnyClient();
  const urls = readFileSync(file, 'utf8')
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith('#'));
  const report: Report = { ok: [], skipped: [], failed: [] };
  for (const url of urls) {
    try {
      const r = parseFxwPost(await fetchHtml(url), url);
      if ('error' in r) {
        report.failed.push({ url, error: r.error });
        console.log(`✗ ${url} — ${r.error}`);
        continue;
      }
      const issues = validateOfr(r.ofr);
      if (hasErrors(issues)) {
        report.failed.push({ url, error: issues.map((i) => `${i.field}: ${i.message}`).join('; ') });
        console.log(`✗ ${url} — invalid: ${issues.map((i) => i.field).join(',')}`);
        continue;
      }
      const hash = ofrHash(r.ofr);
      const existing = await prisma.recipe.findUnique({ where: { hash } });
      if (existing) {
        report.skipped.push({ url, reason: `duplicate of ${existing.id}` });
        console.log(`· ${url} — duplicate (${existing.name})`);
        continue;
      }
      const filmSim = str(r.ofr.film_simulation) ?? 'Provia';
      const created = await prisma.recipe.create({
        data: {
          hash,
          ofr: { ...r.ofr, hash },
          name: (str(r.ofr.name) ?? 'Untitled').slice(0, 60),
          filmSim,
          isMono: isMonoFilmSim(filmSim),
          sensors: strList(r.ofr.sensors),
          sourceUrl: url,
          sourceAttribution: str(r.ofr.source_attribution) ?? 'Fuji X Weekly',
          reviewed: true,
          authorId: null,
          imageUrls: [],
        },
      });
      let images: string[] = [];
      if (withImages && env.bunny.key) {
        images = await uploadImages(bunny, created.id, r.imageUrls, 3);
        if (images.length) await prisma.recipe.update({ where: { id: created.id }, data: { imageUrls: images } });
      }
      report.ok.push({ url, id: created.id, name: created.name, images: images.length });
      console.log(`✓ ${created.name} (${filmSim}) ${images.length ? `+${images.length} img` : ''}`);
    } catch (e) {
      report.failed.push({ url, error: (e as Error).message });
      console.log(`✗ ${url} — ${(e as Error).message}`);
    }
  }
  mkdirSync('seed', { recursive: true });
  writeFileSync(join('seed', 'report.json'), JSON.stringify(report, null, 2));
  console.log(`\nok ${report.ok.length} · skipped ${report.skipped.length} · failed ${report.failed.length} → seed/report.json`);
  await prisma.$disconnect();
}

async function main() {
  const [cmd, arg, ...flags] = process.argv.slice(2);
  if (cmd === 'scrape' && arg) return cmdScrape(arg);
  if (cmd === 'import' && arg) return cmdImport(arg, flags.includes('--images'));
  console.error('usage: seed scrape <url> | seed import <urls.txt> [--images]');
  process.exit(1);
}
void main();
