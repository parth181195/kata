import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Patch,
  UseGuards,
} from '@nestjs/common';
import {
  IsArray,
  IsIn,
  IsISO8601,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { FILM_FAMILIES, SENSORS } from './preferences';
import { AuthUser, CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { toUserDto, UsersService } from './users.service';

/// Validated so a typo can't leave someone staring at an empty library.
export class PreferencesDto {
  // plural: people own more than one body
  @IsOptional() @IsArray() @IsIn(SENSORS, { each: true }) sensors?: string[];
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(40, { each: true })
  bodies?: string[];
  // singular kept for accounts written before multi-body
  @IsOptional() @IsString() @IsIn(SENSORS) sensor?: string;
  @IsOptional() @IsString() @MaxLength(40) body?: string;
  @IsOptional()
  @IsArray()
  @IsIn(FILM_FAMILIES, { each: true })
  filmSimFamilies?: string[];
  @IsOptional() @IsISO8601() onboardedAt?: string;
}

export class UpdateMeDto {
  @IsOptional() @IsString() @MaxLength(30) handle?: string;
  @IsOptional() @IsString() @MaxLength(80) displayName?: string;
  @IsOptional()
  @ValidateNested()
  @Type(() => PreferencesDto)
  preferences?: PreferencesDto;
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
