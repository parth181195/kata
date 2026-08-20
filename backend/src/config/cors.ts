import type { CorsOptions } from '@nestjs/common/interfaces/external/cors-options.interface';

/** Admin SPA (+ local dev). The Android app is native and needs no CORS. */
export const corsOptions: CorsOptions = {
  origin: [
    /^https:\/\/kata\.parthjansari\.dev$/,
    /^https:\/\/admin\.kata\.parthjansari\.dev$/,
    /^http:\/\/localhost:\d+$/,
  ],
  methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'],
  allowedHeaders: ['Authorization', 'Content-Type'],
  maxAge: 600,
};
