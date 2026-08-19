import * as cheerio from 'cheerio';
import { OfrDoc, OfrEnums } from '../../src/ofr';

/** Result of parsing a Fuji X Weekly recipe post. */
export type ParseResult = { ofr: OfrDoc; imageUrls: string[] } | { error: string };

const FILM_SIM_ALIASES: Record<string, string> = {
  'classic chrome': 'Classic Chrome',
  'classic negative': 'Classic Negative',
  'classic neg': 'Classic Negative',
  'classic neg.': 'Classic Negative',
  provia: 'Provia',
  'provia/standard': 'Provia',
  velvia: 'Velvia',
  'velvia/vivid': 'Velvia',
  astia: 'Astia',
  'astia/soft': 'Astia',
  'pro neg. hi': 'Pro Neg. Hi',
  'pro neg hi': 'Pro Neg. Hi',
  'pro neg. std': 'Pro Neg. Std',
  'pro neg std': 'Pro Neg. Std',
  'pro neg. standard': 'Pro Neg. Std',
  eterna: 'Eterna',
  'eterna/cinema': 'Eterna',
  'eterna bleach bypass': 'Eterna Bleach Bypass',
  'bleach bypass': 'Eterna Bleach Bypass',
  'nostalgic neg.': 'Nostalgic Negative',
  'nostalgic neg': 'Nostalgic Negative',
  'nostalgic negative': 'Nostalgic Negative',
  'reala ace': 'Reala Ace',
  acros: 'Acros STD',
  'acros std': 'Acros STD',
  'acros+y': 'Acros Yellow',
  'acros+ye': 'Acros Yellow',
  'acros + y': 'Acros Yellow',
  'acros+r': 'Acros Red',
  'acros + r': 'Acros Red',
  'acros+g': 'Acros Green',
  'acros + g': 'Acros Green',
  monochrome: 'Monochrome STD',
  'monochrome+y': 'Monochrome Yellow',
  'monochrome+ye': 'Monochrome Yellow',
  'monochrome+r': 'Monochrome Red',
  'monochrome+g': 'Monochrome Green',
  sepia: 'Sepia',
};

const MODEL_SENSOR: [RegExp, string][] = [
  [/x-?t5|x-?h2s?|x-?s20|x-?t50|x-?m5|x-?e5|x-?t30 ?iii|x100vi/i, 'X-Trans V'],
  [/x-?t4|x-?t3\b|x-?pro3|x100v\b|x-?s10|x-?e4|x-?t30 ?ii|x-?t30\b/i, 'X-Trans IV'],
  [/x-?t2\b|x-?pro2|x100f|x-?t20|x-?e3|x-?h1/i, 'X-Trans III'],
  [/gfx/i, 'GFX'],
];

const normFilmSimExact = (raw: string): string | undefined => {
  const k = raw.toLowerCase().replace(/\s*filter\s*$/, '').replace(/\s+/g, ' ').trim();
  return FILM_SIM_ALIASES[k] ?? OfrEnums.filmSims.find((f) => f.toLowerCase() === k);
};

/** "Acros/Acros+R/Acros+G" or "Acros (Acros+Y, …)" → first listed option. */
const normFilmSim = (raw: string): string | undefined => {
  const exact = normFilmSimExact(raw);
  if (exact) return exact;
  const first = raw.split(/[/(,]| or /i)[0];
  return first && first !== raw ? normFilmSimExact(first) : undefined;
};

const parseNum = (s: string): number | undefined => {
  const m = s.replace('−', '-').replace('–', '-').match(/[-+]?\d+(?:\.\d+)?/);
  return m ? Number(m[0]) : undefined;
};

const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();

function parseWhiteBalance(v: string, out: OfrDoc) {
  // "Daylight, +2 Red & -5 Blue" | "5800K, +1 Red & -4 Blue" | "Auto, 0 Red & 0 Blue" | "Auto White Priority, …" | "Fluorescent 1, …"
  const [modeRaw, ...rest] = v.split(',');
  const mode = modeRaw.trim();
  const shifts = rest.join(',');
  const red = shifts.match(/([-+]?\d+)\s*red/i);
  const blue = shifts.match(/([-+]?\d+)\s*blue/i);
  out.white_balance_red = red ? Number(red[1]) : 0;
  out.white_balance_blue = blue ? Number(blue[1]) : 0;
  const k = mode.match(/(\d{4,5})\s*k/i);
  if (k) {
    out.white_balance = 'Kelvin';
    out.wb_kelvin = Number(k[1]);
    return;
  }
  const m = mode.toLowerCase();
  if (/white priority/.test(m)) out.white_balance = 'Auto (white priority)';
  else if (/ambience|ambiance/.test(m)) out.white_balance = 'Auto (ambience priority)';
  else if (/^auto|^awb/.test(m)) out.white_balance = 'Auto';
  else if (/fluorescent[^0-9]{0,16}(\d)/.test(m)) out.white_balance = `Fluorescent ${m.match(/fluorescent[^0-9]{0,16}(\d)/)![1]}`;
  else if (/fluorescent/.test(m)) out.white_balance = 'Fluorescent 1';
  else if (/incandescent|tungsten/.test(m)) out.white_balance = 'Incandescent';
  else if (/shade/.test(m)) out.white_balance = 'Shade';
  else if (/daylight|sunlight|sunny/.test(m)) out.white_balance = 'Daylight';
  else if (/underwater/.test(m)) out.white_balance = 'Underwater';
  else if (/custom\s*(\d)/.test(m)) out.white_balance = `Custom ${m.match(/custom\s*(\d)/)![1]}`;
  else if (/custom|manual|preset/.test(m)) out.white_balance = 'Custom 1';
  else out.white_balance = cap(mode);
}

function parseGrain(v: string, out: OfrDoc) {
  const m = v.split(/[;(]|\bor\b/i)[0].toLowerCase();
  if (/off/.test(m)) {
    out.grain_roughness = 'Off';
    return;
  }
  out.grain_roughness = /strong/.test(m) ? 'Strong' : 'Weak';
  out.grain_size = /large/.test(m) ? 'Large' : 'Small';
}

const firstOpt = (v: string) => v.split(/[;(/]| or /i)[0].trim();
const effect = (v: string) => (/strong/i.test(firstOpt(v)) ? 'Strong' : /weak/i.test(firstOpt(v)) ? 'Weak' : 'Off');

/** Parses one Fuji X Weekly recipe post into an OFR document. */
export function parseFxwPost(html: string, url: string): ParseResult {
  const $ = cheerio.load(html);
  const title = $('h1.entry-title').first().text().trim() || $('title').text().split('|')[0].trim();
  const body = $('.entry-content');
  if (!body.length) return { error: 'no .entry-content' };

  // Collect candidate lines: every <p>/<li> split on <br>
  const lines: string[] = [];
  body.find('p, li').each((_, el) => {
    const htmlFrag = $(el).html() ?? '';
    for (const part of htmlFrag.split(/<br\s*\/?>/i)) {
      const t = cheerio.load(`<x>${part}</x>`)('x').text().replace(/ /g, ' ').trim();
      if (t) lines.push(t);
    }
  });
  const anchorRe = /^(dynamic range|d-?range priority|grain effect|highlight|white balance)\s*:/i;
  const drIdx = lines.findIndex((l) => anchorRe.test(l));
  if (drIdx < 0) return { error: 'no recipe lines (Dynamic Range / D-Range Priority / Grain / Highlight) — not a recipe post?' };
  // Anchor the recipe block: an explicit "Film Simulation:" line, else a bare film-sim line shortly before "Dynamic Range:"
  const explicitIdx = lines.findIndex((l, i) => i <= drIdx && /^film sim(ulation)?\s*:/i.test(l));
  let recipeStart = explicitIdx >= 0 ? explicitIdx : -1;
  const out: OfrDoc = { v: 1, d_range_priority: 'Off', grain_roughness: 'Off' };
  const extra: Record<string, unknown> = {};
  let filmSimSet = false;
  if (recipeStart < 0) {
    for (let i = drIdx - 1; i >= Math.max(0, drIdx - 12); i--) {
      const fs = normFilmSim(lines[i]);
      if (fs) {
        out.film_simulation = fs;
        filmSimSet = true;
        recipeStart = i;
        break;
      }
    }
  }
  if (recipeStart < 0) recipeStart = Math.max(0, drIdx - 3);

  for (const line of lines.slice(recipeStart, recipeStart + 30)) {
    const m = line.match(/^([A-Za-z][A-Za-z .&/-]{1,40}?)\s*[:：]\s*(.+)$/);
    if (!m) continue;
    const key = m[1].toLowerCase().replace(/\s+/g, ' ').trim();
    const val = m[2].trim();
    switch (true) {
      case /^film sim/.test(key): {
        const fs = normFilmSim(val);
        if (fs) {
          out.film_simulation = fs;
          filmSimSet = true;
        }
        break;
      }
      case /^dynamic range$/.test(key): {
        const d = val.toUpperCase().replace(/\s+/g, '');
        if (/N\/A|NA$|NONE/.test(d)) break; // older bodies: not set → omit
        out.dynamic_range = /AUTO/.test(d) ? 'DR-Auto' : /400/.test(d) ? 'DR400' : /200/.test(d) ? 'DR200' : 'DR100';
        break;
      }
      case /^d-?(ynamic)? ?range priority$/.test(key): {
        const v0 = firstOpt(val);
        out.d_range_priority = /strong/i.test(v0) ? 'Strong' : /weak/i.test(v0) ? 'Weak' : /auto/i.test(v0) ? 'Auto' : 'Off';
        break;
      }
      case /^highlight/.test(key):
        out.highlight = parseNum(val);
        break;
      case /^shadow/.test(key):
        out.shadow = parseNum(val);
        break;
      case /^colou?r$/.test(key):
        out.color = parseNum(val);
        break;
      case /^sharp/.test(key):
        out.sharpness = parseNum(val);
        break;
      case /noise reduction|high iso nr/.test(key):
        out.high_iso_nr = parseNum(val);
        break;
      case /^clarity$/.test(key):
        out.clarity = parseNum(val);
        break;
      case /^grain/.test(key):
        parseGrain(val, out);
        break;
      case /colou?r chrome (effect )?blue|colou?r chrome fx blue/.test(key):
        out.color_chrome_fx_blue = effect(val);
        break;
      case /colou?r chrome/.test(key):
        out.color_chrome_effect = effect(val);
        break;
      case /^white balance$/.test(key):
        parseWhiteBalance(val, out);
        break;
      case /monochromatic colou?r|warm\/cool|wc/.test(key): {
        const wc = val.match(/([-+]?\d+)\s*(?:wc|warm)/i);
        const mg = val.match(/([-+]?\d+)\s*(?:mg|magenta)/i);
        if (wc) out.monochromatic_color_warm_cool = Number(wc[1]);
        if (mg) out.monochromatic_color_magenta_green = Number(mg[1]);
        break;
      }
      case /^exposure compensation/.test(key): {
        // first number in reading order; fractions like +1/3 become decimals
        const m2 = val.replace('−', '-').match(/([-+]?)(?:(\d)\/(\d)|(\d+(?:\.\d+)?))/);
        if (m2) {
          const sign = m2[1] === '-' ? -1 : 1;
          const n = m2[2] !== undefined ? Number(m2[2]) / Number(m2[3]) : Number(m2[4]);
          extra.x_exposure_comp = Math.round(sign * n * 100) / 100;
        }
        break;
      }
      case /^iso$/.test(key):
        extra.x_iso = val;
        break;
      default:
        break;
    }
  }
  if (!filmSimSet) return { error: 'film simulation not recognised' };

  // omission rules: mono recipes carry no color/color chrome; DRP on drops DR/tones; grain off drops size
  if (OfrEnums.monoFilmSims.has(String(out.film_simulation))) {
    delete out.color;
    delete out.color_chrome_effect;
    delete out.color_chrome_fx_blue;
  } else {
    delete out.monochromatic_color_warm_cool;
    delete out.monochromatic_color_magenta_green;
  }
  if (out.d_range_priority !== 'Off') {
    delete out.dynamic_range;
    delete out.highlight;
    delete out.shadow;
  }
  if (out.grain_roughness === 'Off') delete out.grain_size;
  const mono = OfrEnums.monoFilmSims.has(String(out.film_simulation));
  const drpOn = out.d_range_priority !== 'Off';
  for (const k of ['highlight', 'shadow', 'color', 'sharpness', 'high_iso_nr', 'clarity'] as const) {
    if (k === 'color' && mono) continue;
    if ((k === 'highlight' || k === 'shadow') && drpOn) continue;
    if (out[k] === undefined) out[k] = 0;
  }
  if (out.white_balance === undefined) {
    out.white_balance = 'Auto';
    out.white_balance_red = 0;
    out.white_balance_blue = 0;
  }

  // envelope
  const name = title
    .replace(/^my\s+/i, '')
    .replace(/fujifilm\s+[A-Za-z0-9-]+\s+/i, '')
    .replace(/\s*[—–-]\s*fujifilm.*$/i, '')
    .replace(/\s*\(x-trans [ivx]+\)\s*/i, ' ')
    .replace(/\s*film simulation recipe.*$/i, '')
    .replace(/\s*recipe$/i, '')
    .replace(/[\s—–-]+$/g, '')
    .trim()
    .slice(0, 25);
  out.name = name || 'Untitled';
  out.source_url = url;
  out.source_attribution = 'Fuji X Weekly';
  const tagText = [title, ...$('a[rel="tag"], a[rel="category tag"]').map((_, a) => $(a).text()).get()].join(' ');
  const sensors = new Set<string>();
  for (const [re, sensor] of MODEL_SENSOR) if (re.test(tagText)) sensors.add(sensor);
  for (const s of OfrEnums.sensors) if (new RegExp(`\\b${s.replace('-', '-?')}\\b(?!I)`, 'i').test(tagText)) sensors.add(s);
  out.sensors = [...sensors];
  Object.assign(out, extra);

  const imageUrls: string[] = [];
  body.find('img').each((_, img) => {
    const $i = $(img);
    if ($i.hasClass('avatar') || $i.attr('data-attachment-id') === undefined) return;
    const src = ($i.attr('data-orig-file') ?? $i.attr('src') ?? '').split('?')[0].replace(/&amp;/g, '&');
    if (src && !imageUrls.includes(src)) imageUrls.push(src);
  });
  return { ofr: out, imageUrls };
}
