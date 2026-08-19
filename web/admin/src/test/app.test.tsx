import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import { ApiClient } from '../api/client';
import App from '../App';
import { AuthProvider } from '../auth/AuthProvider';
import { ToastHost } from '../ui';

const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

function mount(client: ApiClient, path = '/') {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={qc}><AuthProvider client={client}><ToastHost><MemoryRouter initialEntries={[path]}><App /></MemoryRouter></ToastHost></AuthProvider></QueryClientProvider>,
  );
}

describe('App gate', () => {
  it('no session → sign-in screen', async () => {
    const c = new ApiClient('https://t', async () => json(500, {}), null);
    mount(c);
    await waitFor(() => expect(screen.getByText('KATA ADMIN')).toBeInTheDocument());
  });

  it('restored session but role=user → Not an admin', async () => {
    const store = { v: new Map<string, string>() };
    const storage = { getItem: (k: string) => store.v.get(k) ?? null, setItem: (k: string, v: string) => void store.v.set(k, v), removeItem: (k: string) => void store.v.delete(k), clear: () => store.v.clear(), key: () => null, length: 0 } as Storage;
    storage.setItem('kata.admin.refresh', 'R1');
    const c = new ApiClient('https://t', async (input) => {
      const u = String(input);
      if (u.endsWith('/auth/refresh')) return json(200, { accessToken: 'A', refreshToken: 'R2', expiresIn: 900, user: {} });
      if (u.endsWith('/me')) return json(200, { id: 'u1', email: 'x@y.z', displayName: 'X', photoUrl: null, role: 'user' });
      return json(404, {});
    }, storage);
    mount(c);
    await waitFor(() => expect(screen.getByText('NOT AN ADMIN')).toBeInTheDocument());
  });

  it('admin → review queue with stats + rows', async () => {
    const storage = new Map<string, string>();
    const st = { getItem: (k: string) => storage.get(k) ?? null, setItem: (k: string, v: string) => void storage.set(k, v), removeItem: (k: string) => void storage.delete(k), clear: () => storage.clear(), key: () => null, length: 0 } as Storage;
    st.setItem('kata.admin.refresh', 'R1');
    const recipe = { id: 'r1', ofr: { dynamic_range: 'DR400' }, hash: 'h', name: 'Kodachrome 64', filmSim: 'Classic Chrome', isMono: false, sensors: ['X-Trans IV'], sourceUrl: null, sourceAttribution: 'Fuji X Weekly', authorId: null, reviewed: false, hidden: false, imageUrls: [], favouritesCount: 0, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(), author: null, openReports: 0, fieldCount: 12, issues: [] };
    const c = new ApiClient('https://t', async (input) => {
      const u = String(input);
      if (u.endsWith('/auth/refresh')) return json(200, { accessToken: 'A', refreshToken: 'R2', expiresIn: 900, user: {} });
      if (u.endsWith('/me')) return json(200, { id: 'u1', email: 'a@y.z', displayName: 'Admin', photoUrl: null, role: 'admin' });
      if (u.includes('/admin/stats')) return json(200, { pending: 1, reported: 0, published: 340, hidden: 2, users: 3, recipes: 343, openReports: 0, oldestPendingAt: null });
      if (u.includes('/admin/queue')) return json(200, { items: [recipe], nextCursor: null });
      return json(404, {});
    }, st);
    mount(c);
    await waitFor(() => expect(screen.getByText('Kodachrome 64')).toBeInTheDocument());
    expect(screen.getAllByText('340').length).toBeGreaterThan(0);
    expect(screen.getByText('PENDING')).toBeInTheDocument();
    expect(screen.getByText('12/22')).toBeInTheDocument();
  });
});
