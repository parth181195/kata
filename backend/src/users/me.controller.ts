import { Controller, Get, NotFoundException, UseGuards } from '@nestjs/common';
import { AuthUser, CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { toUserDto, UsersService } from './users.service';

@Controller('me')
@UseGuards(JwtAuthGuard)
export class MeController {
  constructor(private readonly users: UsersService) {}

  @Get()
  async me(@CurrentUser() u: AuthUser) {
    const user = await this.users.findById(u.id);
    if (!user) throw new NotFoundException();
    return toUserDto(user);
  }
}
