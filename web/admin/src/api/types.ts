export type Role = 'user' | 'admin';
export interface UserDto { id: string; email: string; displayName: string; photoUrl: string | null; role: Role }
export interface Tokens { accessToken: string; refreshToken: string; expiresIn: number; user: UserDto }
export type Ofr = Record<string, unknown> & { name?: string; film_simulation?: string; dynamic_range?: string; sensors?: string[]; source_url?: string; source_attribution?: string; hash?: string };
export interface OfrIssue { field: string; message: string; severity: 'error' | 'warning' }
export interface RecipeDto {
  id: string; ofr: Ofr; hash: string; name: string; filmSim: string; isMono: boolean; sensors: string[];
  sourceUrl: string | null; sourceAttribution: string | null; authorId: string | null; reviewed: boolean; hidden: boolean;
  imageUrls: string[]; favouritesCount: number; createdAt: string; updatedAt: string;
}
export interface AdminRecipe extends RecipeDto {
  author: Pick<UserDto, 'id' | 'email' | 'displayName' | 'photoUrl'> | null;
  openReports: number; fieldCount: number; issues: OfrIssue[];
  reports?: ReportDto[];
}
export interface AdminUser extends UserDto { createdAt: string; recipeCount: number; reportCount: number }
export interface ReportDto {
  id: string; reason: string; createdAt: string; resolvedAt: string | null;
  recipe: { id: string; name: string; filmSim: string; hidden: boolean };
  user: { id: string; email: string; displayName: string };
}
export interface Stats { pending: number; reported: number; published: number; hidden: number; users: number; recipes: number; openReports: number; oldestPendingAt: string | null }
export interface Page<T> { items: T[]; nextCursor: string | null }
export type QueueTab = 'pending' | 'reported' | 'published' | 'hidden' | 'all';
export type BulkAction = 'approve' | 'verify' | 'hide' | 'unhide';
export interface CameraProfiles {
  updatedAt: string; fields: string[];
  generations: { id: string; bodies: string[]; slots: number; slotsNote?: string; filmSims: number; usbWrite: 'full' | 'probe' | 'none'; tested: string[]; unsupported: string[]; note?: string }[];
}
export interface CameraSeen { model: string; firmware: string; slots: number; users: number; connections: number; lastSeen: string | null }
