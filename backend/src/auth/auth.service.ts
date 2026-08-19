import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { User } from '@prisma/client';
import { createHash, randomBytes } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { toUserDto, UserDto, UsersService } from '../users/users.service';
import { GoogleVerifier } from './google-verifier';

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: number; // seconds
}

const ACCESS_TTL_S = 15 * 60;
const REFRESH_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const sha256 = (s: string) => createHash('sha256').update(s).digest('hex');

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly jwt: JwtService,
    private readonly google: GoogleVerifier,
  ) {}

  async googleSignIn(idToken: string): Promise<TokenPair & { user: UserDto }> {
    let identity;
    try {
      identity = await this.google.verify(idToken);
    } catch {
      throw new UnauthorizedException('Invalid Google token');
    }
    const user = await this.users.upsertFromGoogle(identity);
    const pair = await this.issue(user);
    return { ...pair, user: toUserDto(user) };
  }

  async refresh(refreshToken: string): Promise<TokenPair> {
    const row = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: sha256(refreshToken) },
      include: { user: true },
    });
    if (!row) throw new UnauthorizedException();
    if (row.revokedAt) {
      // reuse of a rotated token: revoke the whole family
      await this.prisma.refreshToken.updateMany({
        where: { userId: row.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      throw new UnauthorizedException();
    }
    if (row.expiresAt < new Date()) throw new UnauthorizedException();
    await this.prisma.refreshToken.update({
      where: { id: row.id },
      data: { revokedAt: new Date() },
    });
    return this.issue(row.user);
  }

  async logout(refreshToken: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash: sha256(refreshToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private async issue(user: User): Promise<TokenPair> {
    const accessToken = await this.jwt.signAsync(
      { sub: user.id, role: user.role },
      { expiresIn: ACCESS_TTL_S },
    );
    const refreshToken = randomBytes(32).toString('base64url');
    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: sha256(refreshToken),
        expiresAt: new Date(Date.now() + REFRESH_TTL_MS),
      },
    });
    return { accessToken, refreshToken, expiresIn: ACCESS_TTL_S };
  }
}
