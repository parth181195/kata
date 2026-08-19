import type { Tokens } from './types';

export const API_BASE: string = (import.meta.env.VITE_API as string | undefined) ?? 'https://api.kata.parthjansari.dev';
const REFRESH_KEY = 'kata.admin.refresh';

export class ApiError extends Error {
  readonly status: number | null;
  readonly body?: unknown;
  constructor(message: string, status: number | null, body?: unknown) { super(message); this.status = status; this.body = body; }
  get isNetwork() { return this.status === null; }
}

type Listener = () => void;

/** Small fetch wrapper: bearer access token in memory, refresh token in localStorage, single-flight refresh on 401. */
export class ApiClient {
  readonly base: string;
  private readonly fetchFn: typeof fetch;
  private readonly storage: Storage | null;
  private access: string | null = null;
  private refreshing: Promise<boolean> | null = null;
  private listeners = new Set<Listener>();
  constructor(base: string = API_BASE, fetchFn: typeof fetch = (...a) => fetch(...a), storage: Storage | null = typeof localStorage === 'undefined' ? null : localStorage) {
    this.base = base; this.fetchFn = fetchFn; this.storage = storage;
  }

  get refreshToken(): string | null { return this.storage?.getItem(REFRESH_KEY) ?? null; }
  get hasSession(): boolean { return !!this.refreshToken; }
  onSessionLost(l: Listener) { this.listeners.add(l); return () => this.listeners.delete(l); }

  setTokens(t: Pick<Tokens, 'accessToken' | 'refreshToken'>) {
    this.access = t.accessToken;
    this.storage?.setItem(REFRESH_KEY, t.refreshToken);
  }
  clear() {
    this.access = null;
    this.storage?.removeItem(REFRESH_KEY);
  }

  async request<T>(method: string, path: string, opts: { body?: unknown; auth?: boolean; form?: FormData; retry?: boolean } = {}): Promise<T> {
    const headers: Record<string, string> = {};
    if (opts.body !== undefined) headers['Content-Type'] = 'application/json';
    if (opts.auth !== false && this.access) headers.Authorization = `Bearer ${this.access}`;
    let res: Response;
    try {
      res = await this.fetchFn(this.base + path, { method, headers, body: opts.form ?? (opts.body === undefined ? undefined : JSON.stringify(opts.body)) });
    } catch (e) {
      throw new ApiError((e as Error).message || 'Network error', null);
    }
    if (res.status === 401 && opts.auth !== false && !opts.retry && !path.startsWith('/auth/')) {
      if (await this.refresh()) return this.request<T>(method, path, { ...opts, retry: true });
      throw new ApiError('Session expired', 401);
    }
    if (res.status === 204) return undefined as T;
    const text = await res.text();
    const data: unknown = text ? safeJson(text) : undefined;
    if (!res.ok) {
      const msg = (data as { message?: string | string[] } | undefined)?.message;
      throw new ApiError(Array.isArray(msg) ? msg.join(', ') : (msg ?? `HTTP ${res.status}`), res.status, data);
    }
    return data as T;
  }

  /** Exchange the stored refresh token for a new pair. Single-flight. */
  refresh(): Promise<boolean> {
    if (this.refreshing) return this.refreshing;
    const rt = this.refreshToken;
    if (!rt) return Promise.resolve(false);
    this.refreshing = (async () => {
      try {
        const t = await this.request<Tokens>('POST', '/auth/refresh', { body: { refreshToken: rt }, auth: false });
        this.setTokens(t);
        return true;
      } catch {
        this.clear();
        this.listeners.forEach((l) => l());
        return false;
      } finally {
        this.refreshing = null;
      }
    })();
    return this.refreshing;
  }

  get<T>(path: string) { return this.request<T>('GET', path); }
  post<T>(path: string, body?: unknown) { return this.request<T>('POST', path, { body }); }
  patch<T>(path: string, body?: unknown) { return this.request<T>('PATCH', path, { body }); }
  del<T>(path: string) { return this.request<T>('DELETE', path); }
  upload<T>(path: string, form: FormData) { return this.request<T>('POST', path, { form }); }
}

function safeJson(t: string): unknown {
  try { return JSON.parse(t); } catch { return t; }
}

export const api = new ApiClient();
