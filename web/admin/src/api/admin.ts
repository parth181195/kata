import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useAuth } from '../auth/AuthProvider';
import type { AdminRecipe, AdminUser, BulkAction, CameraProfiles, Page, QueueTab, ReportDto, Stats } from './types';

const qs = (o: Record<string, string | number | undefined | null>) => {
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(o)) if (v !== undefined && v !== null && v !== '') p.set(k, String(v));
  const s = p.toString();
  return s ? `?${s}` : '';
};

export const useStats = () => { const { client: api } = useAuth(); return useQuery({ queryKey: ['stats'], queryFn: () => api.get<Stats>('/admin/stats'), refetchInterval: 60_000 }); };

export interface QueueFilter { tab: QueueTab; q?: string; sensor?: string; filmSim?: string }
export const useQueue = (f: QueueFilter) => {
  const { client: api } = useAuth();
  return useInfiniteQuery({
    queryKey: ['queue', f],
    queryFn: ({ pageParam }) => api.get<Page<AdminRecipe>>(`/admin/queue${qs({ ...f, cursor: pageParam, limit: 30 })}`),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
};

export const useRecipe = (id: string | null) => {
  const { client: api } = useAuth();
  return useQuery({ queryKey: ['recipe', id], queryFn: () => api.get<AdminRecipe>(`/admin/recipes/${id}`), enabled: !!id });
};

export function useRecipeMutations() {
  const { client: api } = useAuth();
  const qc = useQueryClient();
  const invalidate = () => { void qc.invalidateQueries({ queryKey: ['queue'] }); void qc.invalidateQueries({ queryKey: ['stats'] }); void qc.invalidateQueries({ queryKey: ['recipe'] }); void qc.invalidateQueries({ queryKey: ['reports'] }); };
  const patch = useMutation({ mutationFn: ({ id, body }: { id: string; body: Partial<Pick<AdminRecipe, 'reviewed' | 'hidden' | 'name' | 'sourceAttribution' | 'sourceUrl' | 'sensors' | 'imageUrls'>> }) => api.patch<AdminRecipe>(`/admin/recipes/${id}`, body), onSuccess: invalidate });
  const bulk = useMutation({ mutationFn: ({ ids, action }: { ids: string[]; action: BulkAction }) => api.post<{ updated: number }>('/admin/recipes/bulk', { ids, action }), onSuccess: invalidate });
  const upload = useMutation({ mutationFn: ({ id, file }: { id: string; file: File }) => { const f = new FormData(); f.append('file', file); return api.upload<{ url: string; thumbUrl: string }>(`/admin/recipes/${id}/images`, f); }, onSuccess: invalidate });
  const removeImage = useMutation({ mutationFn: ({ id, index }: { id: string; index: number }) => api.del<AdminRecipe>(`/admin/recipes/${id}/images/${index}`), onSuccess: invalidate });
  return { patch, bulk, upload, removeImage };
}

export const useUsers = (q?: string) => {
  const { client: api } = useAuth();
  return useInfiniteQuery({
    queryKey: ['users', q],
    queryFn: ({ pageParam }) => api.get<Page<AdminUser>>(`/admin/users${qs({ q, cursor: pageParam, limit: 50 })}`),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
};
export function useUserMutations() {
  const { client: api } = useAuth();
  const qc = useQueryClient();
  const role = useMutation({ mutationFn: ({ id, role }: { id: string; role: 'user' | 'admin' }) => api.patch<AdminUser>(`/admin/users/${id}`, { role }), onSuccess: () => { void qc.invalidateQueries({ queryKey: ['users'] }); void qc.invalidateQueries({ queryKey: ['stats'] }); } });
  return { role };
}

export const useReports = (status: 'open' | 'resolved' | 'all') => {
  const { client: api } = useAuth();
  return useInfiniteQuery({
    queryKey: ['reports', status],
    queryFn: ({ pageParam }) => api.get<Page<ReportDto>>(`/admin/reports${qs({ status, cursor: pageParam, limit: 50 })}`),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
};
export function useReportMutations() {
  const { client: api } = useAuth();
  const qc = useQueryClient();
  const resolve = useMutation({ mutationFn: ({ id, resolved }: { id: string; resolved: boolean }) => api.patch<ReportDto>(`/admin/reports/${id}`, { resolved }), onSuccess: () => { void qc.invalidateQueries({ queryKey: ['reports'] }); void qc.invalidateQueries({ queryKey: ['queue'] }); void qc.invalidateQueries({ queryKey: ['stats'] }); void qc.invalidateQueries({ queryKey: ['recipe'] }); } });
  return { resolve };
}

export const useCameraProfiles = () => { const { client: api } = useAuth(); return useQuery({ queryKey: ['camera-profiles'], queryFn: () => api.get<CameraProfiles>('/admin/camera-profiles'), staleTime: Infinity }); };
