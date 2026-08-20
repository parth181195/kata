// Kata Code v1 — encode-only TS port of packages/ofr/lib/src/kata_code.dart (keep the two in step).
import type { Ofr } from './types';

const FILM: Record<string, string> = {
  Provia: 'PV', Velvia: 'VV', Astia: 'AS', 'Classic Chrome': 'CC', 'Pro Neg. Hi': 'PH', 'Pro Neg. Std': 'PS',
  'Classic Negative': 'CN', Eterna: 'ET', 'Eterna Bleach Bypass': 'EB', 'Nostalgic Negative': 'NN', 'Reala Ace': 'RA',
  'Acros STD': 'AC', 'Acros Yellow': 'ACY', 'Acros Red': 'ACR', 'Acros Green': 'ACG',
  'Monochrome STD': 'MO', 'Monochrome Yellow': 'MOY', 'Monochrome Red': 'MOR', 'Monochrome Green': 'MOG', Sepia: 'SP',
};
const WB: Record<string, string> = {
  Auto: 'A', 'Auto (white priority)': 'AW', 'Auto (ambience priority)': 'AA', Daylight: 'D', Shade: 'S', Incandescent: 'I',
  'Fluorescent 1': 'F1', 'Fluorescent 2': 'F2', 'Fluorescent 3': 'F3', Underwater: 'U', 'Custom 1': 'C1', 'Custom 2': 'C2', 'Custom 3': 'C3',
};
const SENSOR: Record<string, string> = {
  'X-Trans I': 'xt1', 'X-Trans II': 'xt2', 'X-Trans III': 'xt3', 'X-Trans IV': 'xt4', 'X-Trans V': 'xt5',
  GFX: 'gfx', Bayer: 'bayer', 'EXR-CMOS': 'exr', 'Full Spectrum': 'fs',
};
const LVL: Record<string, string> = { Off: 'O', Weak: 'W', Strong: 'S', Auto: 'A' };

const sgn = (v: number) => (v > 0 ? `+${v}` : `${v}`);
const sgnAlways = (v: number) => (v >= 0 ? `+${v}` : `${v}`);
const enc = (s: string) => encodeURIComponent(s).replace(/%20/g, '+').replace(/%2C/gi, ',');

export function encodeKataCode(r: Ofr, credit?: string): string {
  const b: string[] = [];
  b.push(FILM[r.film_simulation ?? 'Provia'] ?? 'PV');
  if (r.dynamic_range) b.push(r.dynamic_range === 'DR-Auto' ? 'DRA' : r.dynamic_range);
  if (r.d_range_priority && r.d_range_priority !== 'Off') b.push(`DP-${LVL[r.d_range_priority] ?? 'A'}`);
  let wb = 'WB' + (r.white_balance === 'Kelvin' ? String(r.wb_kelvin ?? 5500) : (WB[r.white_balance ?? 'Auto'] ?? 'A'));
  const wr = r.white_balance_red ?? 0, wbb = r.white_balance_blue ?? 0;
  if (wr !== 0 || wbb !== 0) wb += `/${sgnAlways(wr)}${sgnAlways(wbb)}`;
  b.push(wb);
  const num = (k: string, v: number | undefined) => { if (v) b.push(`${k}${sgn(v)}`); };
  num('HL', r.highlight); num('SD', r.shadow); num('CO', r.color); num('SH', r.sharpness); num('NR', r.high_iso_nr); num('CL', r.clarity);
  if (r.grain_roughness && r.grain_roughness !== 'Off') b.push(`GR-${LVL[r.grain_roughness] ?? 'W'}${r.grain_size === 'Large' ? 'L' : r.grain_size === 'Small' ? 'S' : ''}`);
  if (r.color_chrome_effect != null) b.push(`CCR-${LVL[r.color_chrome_effect] ?? 'W'}`);
  if (r.color_chrome_fx_blue != null) b.push(`CCB-${LVL[r.color_chrome_fx_blue] ?? 'W'}`);
  num('MW', r.monochromatic_color_warm_cool); num('MM', r.monochromatic_color_magenta_green);
  const ec = r['x_exposure_comp'];
  if (typeof ec === 'number' && ec !== 0) b.push(`EC${sgn(ec)}`);
  const meta: string[] = [];
  if (r.name) meta.push(`n=${enc(r.name)}`);
  const a = credit ?? r.source_attribution;
  if (a) meta.push(`a=${enc(a)}`);
  if (r.sensors?.length) meta.push(`v=${r.sensors.map((s) => SENSOR[s] ?? enc(s)).join(',')}`);
  if (r.source_url) meta.push(`u=${enc(r.source_url)}`);
  return `kata1:${b.join(',')}${meta.length ? ';' + meta.join(';') : ''}`;
}
