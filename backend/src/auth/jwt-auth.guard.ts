import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Role } from '@prisma/client';
import { AuthUser } from './current-user.decorator';

interface AccessClaims {
  sub: string;
  role: Role;
}

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<{
      headers: Record<string, string | undefined>;
      user?: AuthUser;
    }>();
    const header = req.headers.authorization ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (!token) throw new UnauthorizedException();
    try {
      const claims = await this.jwt.verifyAsync<AccessClaims>(token);
      req.user = { id: claims.sub, role: claims.role };
      return true;
    } catch {
      throw new UnauthorizedException();
    }
  }
}
