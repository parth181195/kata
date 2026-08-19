import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, Recipe, Report, User } from '@prisma/client';
import { OfrDoc, OfrIssue, validateOfr } from '../ofr';
import { PrismaService } from '../prisma/prisma.service';
import { RecipeDto, toRecipeDto } from '../recipes/recipe.mapper';
import { toUserDto, UserDto } from '../users/users.service';
import { BulkAction } from './dto/bulk.dto';
import { PatchRecipeDto } from './dto/patch-recipe.dto';
import { CursorDto, QueueDto, ReportsQueryDto } from './dto/queue.dto';

export interface AdminRecipeDto extends RecipeDto {
  author: Pick<UserDto, 'id' | 'email' | 'displayName' | 'photoUrl'> | null;
  openReports: number;
  fieldCount: number;
  issues: OfrIssue[];
}
export interface AdminUserDto extends UserDto {
  createdAt: string;
  recipeCount: number;
  reportCount: number;
}
export interface ReportDto {
  id: string;
  reason: string;
  createdAt: string;
  resolvedAt: string | null;
  recipe: { id: string; name: string; filmSim: string; hidden: boolean };
  user: { id: string; email: string; displayName: string };
}

type RecipeRow = Recipe & {
  author: User | null;
  _count: { reports: number };
};
type ReportRow = Report & { recipe: Recipe; user: User };

const encodeCursor = (parts: string[]) =>
  Buffer.from(parts.join('|'), 'utf8').toString('base64url');
const decodeCursor = (c: string) =>
  Buffer.from(c, 'base64url').toString('utf8').split('|');
const SETTING_KEYS = new Set([
  'film_simulation',
  'dynamic_range',
  'd_range_priority',
  'grain_roughness',
  'grain_size',
  'color_chrome_effect',
  'color_chrome_fx_blue',
  'white_balance',
  'wb_kelvin',
  'white_balance_red',
  'white_balance_blue',
  'highlight',
  'shadow',
  'color',
  'sharpness',
  'high_iso_nr',
  'clarity',
  'monochromatic_color_warm_cool',
  'monochromatic_color_magenta_green',
  'smooth_skin_effect',
  'exposure_compensation',
  'iso',
]);

@Injectable()
export class AdminService {
  private readonly log = new Logger(AdminService.name);
  constructor(private readonly prisma: PrismaService) {}

  // ------------------------------------------------------------ mapping
  private toAdminRecipe(r: RecipeRow): AdminRecipeDto {
    const ofr = r.ofr as OfrDoc;
    const fieldCount = Object.keys(ofr ?? {}).filter((k) =>
      SETTING_KEYS.has(k),
    ).length;
    return {
      ...toRecipeDto(r),
      author: r.author
        ? {
            id: r.author.id,
            email: r.author.email,
            displayName: r.author.displayName,
            photoUrl: r.author.photoUrl,
          }
        : null,
      openReports: r._count.reports,
      fieldCount,
      issues: validateOfr(ofr),
    };
  }
  private toReport(r: ReportRow): ReportDto {
    return {
      id: r.id,
      reason: r.reason,
      createdAt: r.createdAt.toISOString(),
      resolvedAt: r.resolvedAt?.toISOString() ?? null,
      recipe: {
        id: r.recipe.id,
        name: r.recipe.name,
        filmSim: r.recipe.filmSim,
        hidden: r.recipe.hidden,
      },
      user: {
        id: r.user.id,
        email: r.user.email,
        displayName: r.user.displayName,
      },
    };
  }
  private readonly recipeInclude = {
    author: true,
    _count: { select: { reports: { where: { resolvedAt: null } } } },
  } satisfies Prisma.RecipeInclude;

  // ------------------------------------------------------------ stats
  async stats() {
    const [pending, reported, published, hidden, users, recipes, openReports] =
      await Promise.all([
        this.prisma.recipe.count({ where: { reviewed: false, hidden: false } }),
        this.prisma.recipe.count({ where: { reportCount: { gt: 0 } } }),
        this.prisma.recipe.count({ where: { reviewed: true, hidden: false } }),
        this.prisma.recipe.count({ where: { hidden: true } }),
        this.prisma.user.count(),
        this.prisma.recipe.count(),
        this.prisma.report.count({ where: { resolvedAt: null } }),
      ]);
    const oldestPending = await this.prisma.recipe.findFirst({
      where: { reviewed: false, hidden: false },
      orderBy: { createdAt: 'asc' },
      select: { createdAt: true },
    });
    return {
      pending,
      reported,
      published,
      hidden,
      users,
      recipes,
      openReports,
      oldestPendingAt: oldestPending?.createdAt.toISOString() ?? null,
    };
  }

  // ------------------------------------------------------------ queue
  async queue(dto: QueueDto) {
    const where: Prisma.RecipeWhereInput = {};
    switch (dto.tab) {
      case 'pending':
        where.reviewed = false;
        where.hidden = false;
        break;
      case 'reported':
        where.reportCount = { gt: 0 };
        break;
      case 'published':
        where.reviewed = true;
        where.hidden = false;
        break;
      case 'hidden':
        where.hidden = true;
        break;
      case 'all':
        break;
    }
    if (dto.sensor) where.sensors = { has: dto.sensor };
    if (dto.filmSim) where.filmSim = dto.filmSim;
    if (dto.q?.trim()) {
      const q = dto.q.trim();
      where.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { sourceAttribution: { contains: q, mode: 'insensitive' } },
        { filmSim: { contains: q, mode: 'insensitive' } },
        { author: { email: { contains: q, mode: 'insensitive' } } },
      ];
    }
    if (dto.cursor) {
      const [a, id] = decodeCursor(dto.cursor);
      const d = new Date(a);
      where.AND = [
        { OR: [{ createdAt: { lt: d } }, { createdAt: d, id: { lt: id } }] },
      ];
    }
    const rows = await this.prisma.recipe.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: dto.limit + 1,
      include: this.recipeInclude,
    });
    const page = rows.slice(0, dto.limit);
    const last = page[page.length - 1];
    return {
      items: page.map((r) => this.toAdminRecipe(r)),
      nextCursor:
        rows.length > dto.limit && last
          ? encodeCursor([last.createdAt.toISOString(), last.id])
          : null,
    };
  }

  async recipe(id: string) {
    const r = await this.prisma.recipe.findUnique({
      where: { id },
      include: {
        ...this.recipeInclude,
        reports: {
          include: { recipe: true, user: true },
          orderBy: { createdAt: 'desc' },
        },
      },
    });
    if (!r) throw new NotFoundException();
    return {
      ...this.toAdminRecipe(r),
      reports: r.reports.map((x) => this.toReport(x)),
    };
  }

  async patchRecipe(id: string, dto: PatchRecipeDto, actorId: string) {
    const existing = await this.prisma.recipe.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException();
    const ofr = { ...(existing.ofr as OfrDoc) };
    if (dto.name !== undefined) ofr.name = dto.name;
    if (dto.sensors !== undefined) ofr.sensors = dto.sensors;
    if (dto.sourceAttribution !== undefined)
      ofr.source_attribution = dto.sourceAttribution;
    if (dto.sourceUrl !== undefined) ofr.source_url = dto.sourceUrl;
    const r = await this.prisma.recipe.update({
      where: { id },
      data: {
        reviewed: dto.reviewed,
        hidden: dto.hidden,
        name: dto.name,
        sensors: dto.sensors,
        sourceAttribution: dto.sourceAttribution,
        sourceUrl: dto.sourceUrl,
        imageUrls: dto.imageUrls,
        ofr: ofr as Prisma.InputJsonValue,
      },
      include: this.recipeInclude,
    });
    this.log.log(
      `admin ${actorId} patched recipe ${id}: ${JSON.stringify(dto)}`,
    );
    return this.toAdminRecipe(r);
  }

  async bulk(ids: string[], action: BulkAction, actorId: string) {
    const data: Prisma.RecipeUpdateManyMutationInput =
      action === 'approve' || action === 'verify'
        ? { reviewed: true, hidden: false }
        : action === 'hide'
          ? { hidden: true }
          : { hidden: false };
    const res = await this.prisma.recipe.updateMany({
      where: { id: { in: ids } },
      data,
    });
    this.log.log(`admin ${actorId} bulk ${action} ×${res.count}`);
    return { updated: res.count };
  }

  async removeImage(id: string, index: number) {
    const r = await this.prisma.recipe.findUnique({ where: { id } });
    if (!r) throw new NotFoundException();
    if (index < 0 || index >= r.imageUrls.length)
      throw new BadRequestException('no image at that index');
    const imageUrls = r.imageUrls.filter((_, i) => i !== index);
    const upd = await this.prisma.recipe.update({
      where: { id },
      data: { imageUrls },
      include: this.recipeInclude,
    });
    return this.toAdminRecipe(upd);
  }

  // ------------------------------------------------------------ users
  async users(dto: CursorDto) {
    const where: Prisma.UserWhereInput = {};
    if (dto.q?.trim()) {
      const q = dto.q.trim();
      where.OR = [
        { email: { contains: q, mode: 'insensitive' } },
        { displayName: { contains: q, mode: 'insensitive' } },
      ];
    }
    if (dto.cursor) {
      const [a, id] = decodeCursor(dto.cursor);
      const d = new Date(a);
      where.AND = [
        { OR: [{ createdAt: { lt: d } }, { createdAt: d, id: { lt: id } }] },
      ];
    }
    const rows = await this.prisma.user.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: dto.limit + 1,
      include: { _count: { select: { recipes: true, reports: true } } },
    });
    const page = rows.slice(0, dto.limit);
    const last = page[page.length - 1];
    return {
      items: page.map((u): AdminUserDto => ({
        ...toUserDto(u),
        createdAt: u.createdAt.toISOString(),
        recipeCount: u._count.recipes,
        reportCount: u._count.reports,
      })),
      nextCursor:
        rows.length > dto.limit && last
          ? encodeCursor([last.createdAt.toISOString(), last.id])
          : null,
    };
  }

  async patchUser(id: string, role: 'user' | 'admin', actorId: string) {
    if (id === actorId && role !== 'admin')
      throw new BadRequestException("You can't demote yourself");
    const u = await this.prisma.user
      .update({
        where: { id },
        data: { role },
        include: { _count: { select: { recipes: true, reports: true } } },
      })
      .catch(() => null);
    if (!u) throw new NotFoundException();
    this.log.log(`admin ${actorId} set user ${id} role=${role}`);
    return {
      ...toUserDto(u),
      createdAt: u.createdAt.toISOString(),
      recipeCount: u._count.recipes,
      reportCount: u._count.reports,
    } satisfies AdminUserDto;
  }

  // ------------------------------------------------------------ reports
  async reports(dto: ReportsQueryDto) {
    const where: Prisma.ReportWhereInput = {};
    if (dto.status === 'open') where.resolvedAt = null;
    if (dto.status === 'resolved') where.resolvedAt = { not: null };
    if (dto.cursor) {
      const [a, id] = decodeCursor(dto.cursor);
      const d = new Date(a);
      where.AND = [
        { OR: [{ createdAt: { lt: d } }, { createdAt: d, id: { lt: id } }] },
      ];
    }
    const rows = await this.prisma.report.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: dto.limit + 1,
      include: { recipe: true, user: true },
    });
    const page = rows.slice(0, dto.limit);
    const last = page[page.length - 1];
    return {
      items: page.map((r) => this.toReport(r)),
      nextCursor:
        rows.length > dto.limit && last
          ? encodeCursor([last.createdAt.toISOString(), last.id])
          : null,
    };
  }

  async patchReport(id: string, resolved: boolean, actorId: string) {
    const existing = await this.prisma.report.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException();
    const wasOpen = existing.resolvedAt === null;
    if (wasOpen === !resolved) {
      const r = await this.prisma.report.findUniqueOrThrow({
        where: { id },
        include: { recipe: true, user: true },
      });
      return this.toReport(r); // no-op
    }
    const r = await this.prisma.$transaction(async (tx) => {
      const upd = await tx.report.update({
        where: { id },
        data: { resolvedAt: resolved ? new Date() : null },
        include: { recipe: true, user: true },
      });
      // keep the denormalised counter in step (floor 0)
      const open = await tx.report.count({
        where: { recipeId: upd.recipeId, resolvedAt: null },
      });
      await tx.recipe.update({
        where: { id: upd.recipeId },
        data: { reportCount: open },
      });
      return upd;
    });
    this.log.log(`admin ${actorId} report ${id} resolved=${resolved}`);
    return this.toReport(r);
  }

  /** User-side: one open report per user+recipe; bumps the recipe's counter. */
  async fileReport(recipeId: string, userId: string, reason: string) {
    const recipe = await this.prisma.recipe.findUnique({
      where: { id: recipeId },
    });
    if (!recipe || recipe.hidden) throw new NotFoundException();
    const dup = await this.prisma.report.findFirst({
      where: { recipeId, userId, resolvedAt: null },
    });
    if (dup) return { id: dup.id, duplicate: true };
    const created = await this.prisma.$transaction(async (tx) => {
      const rep = await tx.report.create({
        data: { recipeId, userId, reason },
      });
      const open = await tx.report.count({
        where: { recipeId, resolvedAt: null },
      });
      await tx.recipe.update({
        where: { id: recipeId },
        data: { reportCount: open },
      });
      return rep;
    });
    return { id: created.id, duplicate: false };
  }
}
