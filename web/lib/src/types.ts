export type Role = 'user' | 'admin';
export interface UserDto { id: string; email: string; displayName: string; photoUrl: string | null; role: Role }
export interface Tokens { accessToken: string; refreshToken: string; expiresIn: number; user: UserDto }
export type Ofr = Record<string, unknown> & {
  name?: string; film_simulation?: string; dynamic_range?: string; d_range_priority?: string;
  grain_roughness?: string; grain_size?: string; color_chrome_effect?: string; color_chrome_fx_blue?: string;
  white_balance?: string; wb_kelvin?: number; white_balance_red?: number; white_balance_blue?: number;
  highlight?: number; shadow?: number; color?: number; sharpness?: number; high_iso_nr?: number; clarity?: number;
  monochromatic_color_warm_cool?: number; monochromatic_color_magenta_green?: number;
  sensors?: string[]; source_url?: string; source_attribution?: string; hash?: string;
};
export interface RecipeDto {
  id: string; ofr: Ofr; hash: string; name: string; filmSim: string; isMono: boolean; sensors: string[];
  sourceUrl: string | null; sourceAttribution: string | null; authorId: string | null; reviewed: boolean; hidden: boolean;
  imageUrls: string[]; favouritesCount: number; createdAt: string; updatedAt: string;
}
export interface Page<T> { items: T[]; nextCursor: string | null }
