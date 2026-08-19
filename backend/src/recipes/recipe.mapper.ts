import { Prisma, Recipe } from '@prisma/client';

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
  createdAt: string;
  updatedAt: string;
}

export const toRecipeDto = (r: Recipe): RecipeDto => ({
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
  imageUrls: r.imageUrls,
  favouritesCount: r.favouritesCount,
  createdAt: r.createdAt.toISOString(),
  updatedAt: r.updatedAt.toISOString(),
});
