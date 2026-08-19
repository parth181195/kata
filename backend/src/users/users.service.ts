import { Injectable } from '@nestjs/common';
import { Role, User } from '@prisma/client';
import { GoogleIdentity } from '../auth/google-verifier';
import { PrismaService } from '../prisma/prisma.service';

export interface UserDto {
  id: string;
  email: string;
  displayName: string;
  photoUrl: string | null;
  role: Role;
}

export const toUserDto = (u: User): UserDto => ({
  id: u.id,
  email: u.email,
  displayName: u.displayName,
  photoUrl: u.photoUrl,
  role: u.role,
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
}
