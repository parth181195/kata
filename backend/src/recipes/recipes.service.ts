import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  hasErrors,
  isMonoFilmSim,
  OfrDoc,
  ofrHash,
  str,
  strList,
  validateOfr,
} from '../ofr';
import { PrismaService } from '../prisma/prisma.service';
import { ListRecipesDto } from './dto/list-recipes.dto';
import { RecipeDto, toRecipeDto } from './recipe.mapper';

export interface ListOpts {
  includeHidden: boolean;
}

export interface CreateRecipeInput {
  ofr: OfrDoc;
  imageUrls?: string[];
  reviewed?: boolean;
  hidden?: boolean;
  authorId?: string | null;
}

const encodeCursor = (parts: string[]) =>
  Buffer.from(parts.join('|'), 'utf8').toString('base64url');
const decodeCursor = (c: string) =>
  Buffer.from(c, 'base64url').toString('utf8').split('|');

@Injectable()
export class RecipesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(
    dto: ListRecipesDto,
    opts: ListOpts,
  ): Promise<{ items: RecipeDto[]; nextCursor: string | null }> {
    const where: Prisma.RecipeWhereInput = {};
    if (!opts.includeHidden) where.hidden = false;
    if (dto.mono !== undefined) where.isMono = dto.mono;
    if (dto.verified) where.reviewed = true;
    if (dto.filmSim) where.filmSim = dto.filmSim;
    if (dto.sensor) where.sensors = { has: dto.sensor };

    if (dto.q?.trim()) {
      const q = dto.q.trim();
      const ids = await this.prisma.$queryRaw<{ id: string }[]>`
        SELECT id FROM "recipes"
        WHERE ("search" @@ plainto_tsquery('simple', ${q}) OR "name" ILIKE ${'%' + q + '%'})
        ORDER BY "createdAt" DESC LIMIT 200`;
      where.id = { in: ids.map((r) => r.id) };
    }

    const popular = dto.sort === 'popular';
    const orderBy: Prisma.RecipeOrderByWithRelationInput[] = popular
      ? [{ favouritesCount: 'desc' }, { id: 'desc' }]
      : [{ createdAt: 'desc' }, { id: 'desc' }];

    if (dto.cursor) {
      const [a, id] = decodeCursor(dto.cursor);
      if (popular) {
        const n = Number(a);
        where.OR = [
          { favouritesCount: { lt: n } },
          { favouritesCount: n, id: { lt: id } },
        ];
      } else {
        const d = new Date(a);
        where.OR = [{ createdAt: { lt: d } }, { createdAt: d, id: { lt: id } }];
      }
    }

    const rows = await this.prisma.recipe.findMany({
      where,
      orderBy,
      take: dto.limit + 1,
    });
    const page = rows.slice(0, dto.limit);
    const last = page[page.length - 1];
    const nextCursor =
      rows.length > dto.limit && last
        ? encodeCursor(
            popular
              ? [String(last.favouritesCount), last.id]
              : [last.createdAt.toISOString(), last.id],
          )
        : null;
    return { items: page.map(toRecipeDto), nextCursor };
  }

  async get(id: string, opts: ListOpts): Promise<RecipeDto> {
    const r = await this.prisma.recipe.findUnique({ where: { id } });
    if (!r || (r.hidden && !opts.includeHidden)) throw new NotFoundException();
    return toRecipeDto(r);
  }

  async byHash(hash: string, opts: ListOpts): Promise<RecipeDto> {
    const r = await this.prisma.recipe.findUnique({ where: { hash } });
    if (!r || (r.hidden && !opts.includeHidden)) throw new NotFoundException();
    return toRecipeDto(r);
  }

  async createCurated(input: CreateRecipeInput): Promise<RecipeDto> {
    const issues = validateOfr(input.ofr);
    if (hasErrors(issues))
      throw new BadRequestException({ message: 'Invalid OFR', issues });
    const hash = ofrHash(input.ofr);
    const existing = await this.prisma.recipe.findUnique({ where: { hash } });
    if (existing)
      throw new ConflictException({
        message: 'Recipe with this hash already exists',
        id: existing.id,
      });
    const ofr: OfrDoc = { ...input.ofr, v: 1, hash };
    const filmSim = str(ofr.film_simulation) ?? 'Provia';
    const r = await this.prisma.recipe.create({
      data: {
        hash,
        ofr: ofr as Prisma.InputJsonValue,
        name: (str(ofr.name) ?? 'Untitled').slice(0, 60),
        filmSim,
        isMono: isMonoFilmSim(filmSim),
        sensors: strList(ofr.sensors),
        sourceUrl: str(ofr.source_url) ?? null,
        sourceAttribution: str(ofr.source_attribution) ?? null,
        authorId: input.authorId ?? null,
        reviewed: input.reviewed ?? false,
        hidden: input.hidden ?? false,
        imageUrls: input.imageUrls ?? [],
      },
    });
    return toRecipeDto(r);
  }

  // ---------------------------------------------------------------- user side (Stage 2)

  /** Publish: public immediately (hidden=false), unreviewed, owned by the user. */
  async createByUser(
    userId: string,
    input: { ofr: OfrDoc; imageUrls?: string[] },
  ): Promise<RecipeDto> {
    return this.createCurated({
      ofr: input.ofr,
      imageUrls: input.imageUrls,
      reviewed: false,
      hidden: false,
      authorId: userId,
    });
  }

  /** Owner edits the OFR document; derived columns + hash re-computed; goes back to the review queue. */
  async updateOwn(
    id: string,
    userId: string,
    ofrIn: OfrDoc,
  ): Promise<RecipeDto> {
    const existing = await this.prisma.recipe.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException();
    if (existing.authorId !== userId) throw new ForbiddenException();
    const issues = validateOfr(ofrIn);
    if (hasErrors(issues))
      throw new BadRequestException({ message: 'Invalid OFR', issues });
    const hash = ofrHash(ofrIn);
    if (hash !== existing.hash) {
      const dup = await this.prisma.recipe.findUnique({ where: { hash } });
      if (dup)
        throw new ConflictException({
          message: 'Recipe with this hash already exists',
          id: dup.id,
        });
    }
    const ofr: OfrDoc = { ...ofrIn, v: 1, hash };
    const filmSim = str(ofr.film_simulation) ?? 'Provia';
    const r = await this.prisma.recipe.update({
      where: { id },
      data: {
        hash,
        ofr: ofr as Prisma.InputJsonValue,
        name: (str(ofr.name) ?? 'Untitled').slice(0, 60),
        filmSim,
        isMono: isMonoFilmSim(filmSim),
        sensors: strList(ofr.sensors),
        sourceUrl: str(ofr.source_url) ?? null,
        sourceAttribution: str(ofr.source_attribution) ?? null,
        reviewed: false,
      },
    });
    return toRecipeDto(r);
  }

  async deleteOwn(id: string, userId: string): Promise<void> {
    const existing = await this.prisma.recipe.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException();
    if (existing.authorId !== userId) throw new ForbiddenException();
    await this.prisma.recipe.delete({ where: { id } });
  }

  async listMine(
    userId: string,
    cursor: string | undefined,
    limit: number,
  ): Promise<{ items: RecipeDto[]; nextCursor: string | null }> {
    const where: Prisma.RecipeWhereInput = { authorId: userId };
    if (cursor) {
      const [a, id] = decodeCursor(cursor);
      const d = new Date(a);
      where.OR = [{ createdAt: { lt: d } }, { createdAt: d, id: { lt: id } }];
    }
    const rows = await this.prisma.recipe.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });
    const page = rows.slice(0, limit);
    const last = page[page.length - 1];
    return {
      items: page.map(toRecipeDto),
      nextCursor:
        rows.length > limit && last
          ? encodeCursor([last.createdAt.toISOString(), last.id])
          : null,
    };
  }

  async assertOwner(id: string, userId: string): Promise<void> {
    const r = await this.prisma.recipe.findUnique({
      where: { id },
      select: { authorId: true, imageUrls: true },
    });
    if (!r) throw new NotFoundException();
    if (r.authorId !== userId) throw new ForbiddenException();
    if (r.imageUrls.length >= 3)
      throw new BadRequestException('Max 3 images per recipe');
  }

  // ---------------------------------------------------------------- favourites
  async setFavourite(
    userId: string,
    recipeId: string,
    on: boolean,
  ): Promise<void> {
    const r = await this.prisma.recipe.findUnique({ where: { id: recipeId } });
    if (!r) throw new NotFoundException();
    await this.prisma.$transaction(async (tx) => {
      if (on) {
        await tx.favourite.upsert({
          where: { userId_recipeId: { userId, recipeId } },
          create: { userId, recipeId },
          update: {},
        });
      } else {
        await tx.favourite.deleteMany({ where: { userId, recipeId } });
      }
      const n = await tx.favourite.count({ where: { recipeId } });
      await tx.recipe.update({
        where: { id: recipeId },
        data: { favouritesCount: n },
      });
    });
  }

  async favouriteIds(userId: string): Promise<string[]> {
    const rows = await this.prisma.favourite.findMany({
      where: { userId },
      select: { recipeId: true },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map((f) => f.recipeId);
  }

  // ---------------------------------------------------------------- cameras
  async recordCamera(
    userId: string,
    c: {
      model: string;
      firmware?: string;
      pid?: number;
      slots: number;
      props?: number;
    },
  ): Promise<void> {
    const firmware = c.firmware ?? '';
    await this.prisma.userCamera.upsert({
      where: { userId_model_firmware: { userId, model: c.model, firmware } },
      create: {
        userId,
        model: c.model,
        firmware,
        pid: c.pid,
        slots: c.slots,
        props: c.props ?? 0,
      },
      update: {
        lastSeen: new Date(),
        seenCount: { increment: 1 },
        slots: c.slots,
        props: c.props ?? 0,
        pid: c.pid,
      },
    });
  }

  async myCameras(userId: string) {
    const rows = await this.prisma.userCamera.findMany({
      where: { userId },
      orderBy: { lastSeen: 'desc' },
    });
    return {
      items: rows.map((r) => ({
        model: r.model,
        firmware: r.firmware,
        pid: r.pid,
        slots: r.slots,
        props: r.props,
        firstSeen: r.firstSeen.toISOString(),
        lastSeen: r.lastSeen.toISOString(),
        seenCount: r.seenCount,
      })),
    };
  }
}
