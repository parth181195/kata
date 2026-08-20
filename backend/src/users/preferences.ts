/// Kept in step with `OfrEnums.sensors` and `FilmFamily.all` in packages/ofr — the API is the
/// thing that stops a bad value reaching a client's filter, so it validates against both.
export const SENSORS = [
  'X-Trans I',
  'X-Trans II',
  'X-Trans III',
  'X-Trans IV',
  'X-Trans V',
  'GFX',
  'Bayer',
  'EXR-CMOS',
  'Full Spectrum',
] as const;

export const FILM_FAMILIES = [
  'classic',
  'vivid',
  'cinematic',
  'portrait',
  'mono',
] as const;

export interface Preferences {
  sensor?: string;
  body?: string;
  filmSimFamilies?: string[];
  onboardedAt?: string;
}
