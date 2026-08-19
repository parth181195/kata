import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { RecipesService } from '../recipes/recipes.service';
import { CreateRecipeDto } from './dto/create-recipe.dto';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminController {
  constructor(private readonly recipes: RecipesService) {}

  @Get('ping')
  ping() {
    return { ok: true };
  }

  @Post('recipes')
  create(@Body() dto: CreateRecipeDto) {
    return this.recipes.createCurated({
      ofr: dto.ofr,
      imageUrls: dto.imageUrls,
      reviewed: dto.reviewed,
      hidden: dto.hidden,
      authorId: null,
    });
  }
}
