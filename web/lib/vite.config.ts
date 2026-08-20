import react from '@vitejs/plugin-react';
import { readFileSync } from 'node:fs';
import { defineConfig } from 'vitest/config';

const pkg = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8')) as { version: string };

// Served from kata.parthjansari.dev/library/ (and /r/* rewrites to the same bundle)
export default defineConfig({
  base: '/library/',
  plugins: [react()],
  define: { __APP_VERSION__: JSON.stringify(pkg.version) },
  test: { environment: 'jsdom', globals: true },
});
