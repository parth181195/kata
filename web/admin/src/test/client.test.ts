import { describe, expect, it } from 'vitest';
import { ApiClient } from '../api/client';

class MemStorage implements Storage {
  m = new Map<string, string>();
  get length() { return this.m.size; }
  clear() { this.m.clear(); }
  getItem(k: string) { return this.m.get(k) ?? null; }
  key(i: number) { return [...this.m.keys()][i] ?? null; }
  removeItem(k: string) { this.m.delete(k); }
  setItem(k: string, v: string) { this.m.set(k, v); }
}
const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

describe('ApiClient', () => {
  it('attaches bearer, refreshes once on 401 and retries; gives up after a failed refresh', async () => {
    const calls: { url: string; auth?: string; body?: string }[] = [];
    let access = 'A1';
    const fetchFn: typeof fetch = async (input, init) => {
      const url = String(input);
      const h = new Headers(init?.headers);
      calls.push({ url, auth: h.get('authorization') ?? undefined, body: init?.body as string | undefined });
      if (url.endsWith('/auth/refresh')) { access = 'A2'; return json(200, { accessToken: 'A2', refreshToken: 'R2', expiresIn: 900, user: {} }); }
      if (url.endsWith('/admin/stats')) return h.get('authorization') === `Bearer ${access}` ? json(200, { pending: 1 }) : json(401, { message: 'Unauthorized' });
      return json(404, {});
    };
    const store = new MemStorage();
    const c = new ApiClient('https://t', fetchFn, store);
    c.setTokens({ accessToken: 'stale', refreshToken: 'R1' });
    const r = await c.get<{ pending: number }>('/admin/stats');
    expect(r.pending).toBe(1);
    expect(calls.map((x) => x.url.replace('https://t', ''))).toEqual(['/admin/stats', '/auth/refresh', '/admin/stats']);
    expect(calls[1].body).toBe(JSON.stringify({ refreshToken: 'R1' }));
    expect(calls[2].auth).toBe('Bearer A2');
    expect(store.getItem('kata.admin.refresh')).toBe('R2');

    // refresh fails → session lost, tokens cleared
    let lost = 0;
    c.onSessionLost(() => lost++);
    const failing = new ApiClient('https://t', async (input) => String(input).endsWith('/auth/refresh') ? json(401, {}) : json(401, {}), store);
    failing.onSessionLost(() => lost++);
    await expect(failing.get('/admin/stats')).rejects.toThrow('Session expired');
    expect(lost).toBe(1);
    expect(store.getItem('kata.admin.refresh')).toBeNull();
  });

  it('maps error bodies and network failures', async () => {
    const c = new ApiClient('https://t', async () => json(400, { message: ['name too long', 'bad url'] }), new MemStorage());
    await expect(c.get('/x')).rejects.toMatchObject({ status: 400, message: 'name too long, bad url' });
    const n = new ApiClient('https://t', async () => { throw new TypeError('Failed to fetch'); }, new MemStorage());
    await expect(n.get('/x')).rejects.toMatchObject({ status: null, isNetwork: true });
  });
});
