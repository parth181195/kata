import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Patch,
  UseGuards,
} from '@nestjs/common';
import { IsOptional, IsString, MaxLength } from 'class-validator';
import { AuthUser, CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { toUserDto, UsersService } from './users.service';

export class UpdateMeDto {
  @IsOptional() @IsString() @MaxLength(30) handle?: string;
  @IsOptional() @IsString() @MaxLength(80) displayName?: string;
}

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

  @Patch()
  async update(@Body() dto: UpdateMeDto, @CurrentUser() u: AuthUser) {
    return toUserDto(await this.users.updateProfile(u.id, dto));
  }
}
