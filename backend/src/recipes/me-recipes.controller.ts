import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { CursorDto } from '../admin/dto/queue.dto';
import { AuthUser, CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ReportCameraDto } from './dto/camera.dto';
import { RecipesService } from './recipes.service';

/** /me/recipes + /me/favourites — lives in RecipesModule to avoid an Auth↔Users↔Recipes import cycle. */
@Controller('me')
@UseGuards(JwtAuthGuard)
export class MeRecipesController {
  constructor(private readonly recipes: RecipesService) {}

  @Get('recipes')
  mine(@Query() dto: CursorDto, @CurrentUser() u: AuthUser) {
    return this.recipes.listMine(u.id, dto.cursor, dto.limit);
  }

  @Get('favourites')
  async favourites(@CurrentUser() u: AuthUser) {
    return { ids: await this.recipes.favouriteIds(u.id) };
  }

  @Put('favourites/:id')
  @HttpCode(204)
  favourite(@Param('id') id: string, @CurrentUser() u: AuthUser) {
    return this.recipes.setFavourite(u.id, id, true);
  }

  @Delete('favourites/:id')
  @HttpCode(204)
  unfavourite(@Param('id') id: string, @CurrentUser() u: AuthUser) {
    return this.recipes.setFavourite(u.id, id, false);
  }

  // ---------------------------------------------------------- cameras
  @Put('cameras')
  @HttpCode(204)
  camera(@Body() dto: ReportCameraDto, @CurrentUser() u: AuthUser) {
    return this.recipes.recordCamera(u.id, dto);
  }

  @Get('cameras')
  cameras(@CurrentUser() u: AuthUser) {
    return this.recipes.myCameras(u.id);
  }
}
