import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { AuthUser, CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ListRecipesDto } from './dto/list-recipes.dto';
import { RecipesService } from './recipes.service';

@Controller('recipes')
@UseGuards(JwtAuthGuard)
export class RecipesController {
  constructor(private readonly recipes: RecipesService) {}

  @Get()
  list(@Query() dto: ListRecipesDto, @CurrentUser() u: AuthUser) {
    return this.recipes.list(dto, { includeHidden: u.role === 'admin' });
  }

  @Get('by-hash/:hash')
  byHash(@Param('hash') hash: string, @CurrentUser() u: AuthUser) {
    return this.recipes.byHash(hash, { includeHidden: u.role === 'admin' });
  }

  @Get(':id')
  get(@Param('id') id: string, @CurrentUser() u: AuthUser) {
    return this.recipes.get(id, { includeHidden: u.role === 'admin' });
  }
}
