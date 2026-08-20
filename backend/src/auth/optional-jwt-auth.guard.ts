import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@prisma/client';
import { AuthUser } from './current-user.decorator';

interface AccessClaims {
  sub: string;
  role: Role;
}

/** Like JwtAuthGuard but anonymous requests pass with `req.user` unset; an invalid token is treated as anonymous. */
@Injectable()
export class OptionalJwtAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<{
      headers: Record<string, string | undefined>;
      user?: AuthUser;
    }>();
    const header = req.headers.authorization ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (!token) return true;
    try {
      const claims = await this.jwt.verifyAsync<AccessClaims>(token);
      req.user = { id: claims.sub, role: claims.role };
    } catch {
      // expired/garbage token on a public read → anonymous, not 401
    }
    return true;
  }
}
