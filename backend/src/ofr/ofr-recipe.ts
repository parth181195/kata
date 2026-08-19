export type OfrDoc = Record<string, unknown>;

export const OFR_ENVELOPE_KEYS = [
  'v',
  'hash',
  'name',
  'sensors',
  'source_url',
  'source_attribution',
] as const;
export const OFR_SETTINGS_KEYS = [
  'film_simulation',
  'dynamic_range',
  'd_range_priority',
  'grain_roughness',
  'grain_size',
  'color_chrome_effect',
  'color_chrome_fx_blue',
  'white_balance',
  'wb_kelvin',
  'white_balance_red',
  'white_balance_blue',
  'highlight',
  'shadow',
  'color',
  'sharpness',
  'high_iso_nr',
  'clarity',
  'monochromatic_color_warm_cool',
  'monochromatic_color_magenta_green',
] as const;

/** Settings fields plus unknown extras — everything except the envelope. */
export function settingsOf(doc: OfrDoc): OfrDoc {
  const envelope = new Set<string>(OFR_ENVELOPE_KEYS);
  const out: OfrDoc = {};
  for (const [k, v] of Object.entries(doc)) {
    if (!envelope.has(k) && v !== undefined) out[k] = v;
  }
  return out;
}

export const str = (v: unknown): string | undefined =>
  typeof v === 'string' ? v : undefined;
export const num = (v: unknown): number | undefined =>
  typeof v === 'number' && Number.isFinite(v) ? v : undefined;
export const strList = (v: unknown): string[] =>
  Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : [];
