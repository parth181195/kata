import {
  BadRequestException,
  ConflictException,
  Injectable,
} from '@nestjs/common';
import { Prisma, Role, User } from '@prisma/client';
import { GoogleIdentity } from '../auth/google-verifier';
import { Preferences } from './preferences';
import { PrismaService } from '../prisma/prisma.service';

export interface UserDto {
  id: string;
  email: string;
  displayName: string;
  photoUrl: string | null;
  role: Role;
  handle: string | null;
  preferences: Preferences;
}

export const toUserDto = (u: User): UserDto => ({
  id: u.id,
  email: u.email,
  displayName: u.displayName,
  photoUrl: u.photoUrl,
  role: u.role,
  handle: u.handle,
  preferences: (u.preferences ?? {}) as Preferences,
});

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  upsertFromGoogle(id: GoogleIdentity): Promise<User> {
    return this.prisma.user.upsert({
      where: { googleSub: id.sub },
      create: {
        googleSub: id.sub,
        email: id.email,
        displayName: id.name,
        photoUrl: id.picture ?? null,
      },
      update: {
        email: id.email,
        displayName: id.name,
        photoUrl: id.picture ?? null,
      },
    });
  }

  findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  /** Claim / change the public @handle (lowercase; letters, digits, dot, underscore; 3–20). */
  async updateProfile(
    id: string,
    patch: { handle?: string; displayName?: string; preferences?: Preferences },
  ): Promise<User> {
    const data: Prisma.UserUpdateInput = {};
    if (patch.preferences !== undefined) {
      // merge: the onboarding writes one step at a time, and Settings edits one key
      const current = await this.prisma.user.findUnique({
        where: { id },
        select: { preferences: true },
      });
      // class-transformer materialises absent DTO fields as `undefined` own-properties, and
      // spreading those would wipe stored keys instead of leaving them alone
      const incoming = Object.fromEntries(
        Object.entries(patch.preferences).filter(([, v]) => v !== undefined),
      );
      data.preferences = {
        ...((current?.preferences ?? {}) as Preferences),
        ...incoming,
      };
    }
    if (patch.displayName !== undefined) {
      const d = patch.displayName.trim();
      if (d.length < 2 || d.length > 60)
        throw new BadRequestException('Display name must be 2–60 characters');
      data.displayName = d;
    }
    if (patch.handle !== undefined) {
      const h = patch.handle.trim().toLowerCase().replace(/^@/, '');
      if (!/^[a-z0-9][a-z0-9._]{1,18}[a-z0-9]$/.test(h))
        throw new BadRequestException(
          'Handles are 3–20 characters: lowercase letters, digits, dots or underscores; no leading/trailing punctuation',
        );
      const taken = await this.prisma.user.findUnique({ where: { handle: h } });
      if (taken && taken.id !== id)
        throw new ConflictException({ message: `@${h} is taken` });
      data.handle = h;
    }
    return this.prisma.user.update({ where: { id }, data });
  }
}
