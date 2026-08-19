import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ImagesService } from '../images/images.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { RecipesService } from '../recipes/recipes.service';
import { CreateRecipeDto } from './dto/create-recipe.dto';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminController {
  constructor(
    private readonly recipes: RecipesService,
    private readonly images: ImagesService,
  ) {}

  @Get('ping')
  ping() {
    return { ok: true };
  }

  @Post('recipes/:id/images')
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }),
  )
  upload(@Param('id') id: string, @UploadedFile() file?: Express.Multer.File) {
    if (!file) throw new BadRequestException('file is required');
    return this.images.uploadRecipeImage(id, {
      buffer: file.buffer,
      mimetype: file.mimetype,
    });
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
