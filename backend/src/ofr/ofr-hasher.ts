import { createHash } from 'node:crypto';
import { OfrDoc, settingsOf, strList } from './ofr-recipe';

export type HashScheme = 'v1Sensors' | 'v1SettingsOnly';

function canon(v: unknown): unknown {
  if (typeof v === 'number') return Number.isInteger(v) ? v : v; // JS has no 2.0 vs 2 distinction
  if (Array.isArray(v)) return v.map(canon);
  if (v && typeof v === 'object') {
    const o = v as Record<string, unknown>;
    return Object.fromEntries(
      Object.keys(o)
        .sort()
        .map((k) => [k, canon(o[k])]),
    );
  }
  return v;
}

/** Sorted keys (recursively), compact JSON. */
export function canonicalJson(payload: OfrDoc): string {
  return JSON.stringify(canon(payload));
}

export function ofrHash(doc: OfrDoc, scheme: HashScheme = 'v1Sensors'): string {
  const payload = settingsOf(doc);
  if (scheme === 'v1Sensors') payload.sensors = strList(doc.sensors);
  return createHash('sha256')
    .update(Buffer.from(canonicalJson(payload), 'utf8'))
    .digest('hex');
}
