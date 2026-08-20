import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useAuth } from './AuthProvider';
import type { Ofr, Page, RecipeDto } from './types';

const qs = (o: Record<string, string | number | undefined | null>) => {
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(o)) if (v !== undefined && v !== null && v !== '') p.set(k, String(v));
  const s = p.toString();
  return s ? `?${s}` : '';
};

export interface Filter { q?: string; sensor?: string; filmSim?: string; mono?: boolean; verified?: boolean; sort?: 'newest' | 'popular' }

export const useRecipes = (f: Filter) => {
  const { client: api } = useAuth();
  return useInfiniteQuery({
    queryKey: ['recipes', f],
    queryFn: ({ pageParam }) => api.get<Page<RecipeDto>>(`/recipes${qs({ ...f, mono: f.mono === undefined ? undefined : String(f.mono), verified: f.verified ? 'true' : undefined, cursor: pageParam, limit: 30 })}`),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
};

export const useRecipe = (id: string | undefined) => {
  const { client: api } = useAuth();
  return useQuery({ queryKey: ['recipe', id], queryFn: () => api.get<RecipeDto>(`/recipes/${id}`), enabled: !!id });
};

export const useFavourites = () => {
  const { client: api, status } = useAuth();
  return useQuery({ queryKey: ['favs'], queryFn: () => api.get<{ ids: string[] }>('/me/favourites'), enabled: status === 'signedIn', select: (d) => new Set(d.ids) });
};

export function useToggleFavourite() {
  const { client: api } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, on }: { id: string; on: boolean }) => (on ? api.request<void>('PUT', `/me/favourites/${id}`) : api.del<void>(`/me/favourites/${id}`)),
    onSuccess: () => { void qc.invalidateQueries({ queryKey: ['favs'] }); void qc.invalidateQueries({ queryKey: ['recipe'] }); },
  });
}

export const useMine = () => {
  const { client: api, status } = useAuth();
  return useQuery({ queryKey: ['mine'], queryFn: () => api.get<Page<RecipeDto>>('/me/recipes?limit=50'), enabled: status === 'signedIn' });
};

export interface OfrIssue { field: string; message: string; severity: string }
export class PublishConflict extends Error { constructor(readonly existingId: string) { super('exists'); } }
export class PublishInvalid extends Error { constructor(readonly issues: OfrIssue[]) { super('invalid'); } }

export function usePublish() {
  const { client: api } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ofr }: { id?: string; ofr: Ofr }) => {
      try {
        return id ? await api.patch<RecipeDto>(`/recipes/${id}`, { ofr }) : await api.post<RecipeDto>('/recipes', { ofr });
      } catch (e) {
        const err = e as { status?: number | null; body?: unknown };
        const body = err.body as { id?: string; issues?: OfrIssue[] } | undefined;
        if (err.status === 409 && body?.id) throw new PublishConflict(body.id);
        if (err.status === 400 && body?.issues) throw new PublishInvalid(body.issues);
        throw e;
      }
    },
    onSuccess: () => { void qc.invalidateQueries({ queryKey: ['mine'] }); void qc.invalidateQueries({ queryKey: ['recipes'] }); void qc.invalidateQueries({ queryKey: ['recipe'] }); },
  });
}

export function useDelete() {
  const { client: api } = useAuth();
  const qc = useQueryClient();
  return useMutation({ mutationFn: (id: string) => api.del<void>(`/recipes/${id}`), onSuccess: () => { void qc.invalidateQueries({ queryKey: ['mine'] }); void qc.invalidateQueries({ queryKey: ['recipes'] }); } });
}

export function useReport() {
  const { client: api } = useAuth();
  return useMutation({ mutationFn: ({ id, reason }: { id: string; reason: string }) => api.post<unknown>(`/recipes/${id}/report`, { reason }) });
}

export const specSummary = (o: Ofr) => `${o.film_simulation ?? '—'} · ${o.dynamic_range ?? 'DR—'} · ${o.white_balance === 'Kelvin' ? `${o.wb_kelvin}K` : (o.white_balance ?? 'AUTO')}`;
