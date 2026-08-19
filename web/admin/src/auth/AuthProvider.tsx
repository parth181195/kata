import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { api, ApiClient } from '../api/client';
import type { Tokens, UserDto } from '../api/types';

interface AuthState {
  status: 'booting' | 'signedOut' | 'signedIn';
  user: UserDto | null;
  error: string | null;
  signInWithCredential(idToken: string): Promise<void>;
  signOut(): Promise<void>;
  client: ApiClient;
}
const Ctx = createContext<AuthState | null>(null);

export function AuthProvider({ children, client = api }: { children: ReactNode; client?: ApiClient }) {
  const [status, setStatus] = useState<AuthState['status']>('booting');
  const [user, setUser] = useState<UserDto | null>(null);
  const [error, setError] = useState<string | null>(null);

  // restore: refresh token → access → /me
  useEffect(() => {
    let live = true;
    (async () => {
      if (!client.hasSession) { setStatus('signedOut'); return; }
      const ok = await client.refresh();
      if (!live) return;
      if (!ok) { setStatus('signedOut'); return; }
      try {
        const me = await client.get<UserDto>('/me');
        if (!live) return;
        setUser(me); setStatus('signedIn');
      } catch { if (live) { client.clear(); setStatus('signedOut'); } }
    })();
    const off = client.onSessionLost(() => { setUser(null); setStatus('signedOut'); });
    return () => { live = false; off(); };
  }, [client]);

  const signInWithCredential = useCallback(async (idToken: string) => {
    setError(null);
    try {
      const t = await client.post<Tokens>('/auth/google', { idToken });
      client.setTokens(t);
      setUser(t.user); setStatus('signedIn');
    } catch (e) { setError((e as Error).message); setStatus('signedOut'); }
  }, [client]);

  const signOut = useCallback(async () => {
    const rt = client.refreshToken;
    if (rt) { try { await client.request('POST', '/auth/logout', { body: { refreshToken: rt }, auth: false }); } catch { /* best effort */ } }
    client.clear();
    window.google?.accounts.id.disableAutoSelect();
    setUser(null); setStatus('signedOut');
  }, [client]);

  const value = useMemo<AuthState>(() => ({ status, user, error, signInWithCredential, signOut, client }), [status, user, error, signInWithCredential, signOut, client]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAuth(): AuthState {
  const v = useContext(Ctx);
  if (!v) throw new Error('useAuth outside AuthProvider');
  return v;
}
