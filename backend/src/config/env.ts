function req(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env ${name}`);
  return v;
}

export const env = {
  port: Number(process.env.PORT ?? 5090),
  nodeEnv: process.env.NODE_ENV ?? 'development',
  databaseUrl: req('DATABASE_URL'),
  jwtSecret: req('JWT_SECRET'),
  googleWebClientId: process.env.GOOGLE_WEB_CLIENT_ID ?? '',
  /** Additional accepted ID-token audiences (comma-separated) — e.g. the Desktop OAuth client. */
  googleExtraClientIds: (process.env.GOOGLE_EXTRA_CLIENT_IDS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
  bunny: {
    zone: process.env.BUNNY_STORAGE_ZONE ?? '',
    key: process.env.BUNNY_STORAGE_KEY ?? '',
    host: process.env.BUNNY_STORAGE_HOST ?? 'storage.bunnycdn.com',
    pullZoneHost: process.env.BUNNY_PULL_ZONE_HOST ?? '',
    /** Folder inside the storage zone (the zone is shared with other projects) — e.g. `kata`. */
    prefix: (process.env.BUNNY_PREFIX ?? '').replace(/^\/+|\/+$/g, ''),
  },
};
export type Env = typeof env;
