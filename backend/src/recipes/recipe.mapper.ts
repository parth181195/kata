import { Prisma, Recipe, User } from '@prisma/client';

export interface RecipeDto {
  id: string;
  ofr: Prisma.JsonValue;
  hash: string;
  name: string;
  filmSim: string;
  isMono: boolean;
  sensors: string[];
  sourceUrl: string | null;
  sourceAttribution: string | null;
  authorId: string | null;
  reviewed: boolean;
  hidden: boolean;
  imageUrls: string[];
  favouritesCount: number;
  version: number;
  /** Present when the query included the author relation — for @handle credit lines. */
  authorHandle: string | null;
  authorName: string | null;
  createdAt: string;
  updatedAt: string;
}

/// How many sample frames a *list* response carries per recipe. Cards show one and the
/// phone's strip shows a few; sending all twelve made a page of fifty 117 KB, nearly half of
/// it image URLs, which is what a pull-to-refresh was waiting on. The full set is one
/// GET /recipes/:id away.
export const LIST_IMAGE_LIMIT = 3;

export const toRecipeDto = (
  r: Recipe & { author?: User | null },
  opts: { images?: number } = {},
): RecipeDto => ({
  id: r.id,
  ofr: r.ofr,
  hash: r.hash,
  name: r.name,
  filmSim: r.filmSim,
  isMono: r.isMono,
  sensors: r.sensors,
  sourceUrl: r.sourceUrl,
  sourceAttribution: r.sourceAttribution,
  authorId: r.authorId,
  reviewed: r.reviewed,
  hidden: r.hidden,
  imageUrls: opts.images === undefined ? r.imageUrls : r.imageUrls.slice(0, opts.images),
  favouritesCount: r.favouritesCount,
  version: r.version,
  authorHandle: r.author?.handle ?? null,
  authorName: r.author?.displayName ?? null,
  createdAt: r.createdAt.toISOString(),
  updatedAt: r.updatedAt.toISOString(),
});
