import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { AuthUser, CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/optional-jwt-auth.guard';
import { ImagesService } from '../images/images.service';
import { ListRecipesDto } from './dto/list-recipes.dto';
import { PublishRecipeDto, UpdateRecipeDto } from './dto/user-recipe.dto';
import { RecipesService } from './recipes.service';

@Controller('recipes')
export class RecipesController {
  constructor(
    private readonly recipes: RecipesService,
    private readonly images: ImagesService,
  ) {}

  // Reads are public (the web library browses without an account); hidden stays admin-only.
  @Get()
  @UseGuards(OptionalJwtAuthGuard)
  list(@Query() dto: ListRecipesDto, @CurrentUser() u: AuthUser | undefined) {
    return this.recipes.list(dto, { includeHidden: u?.role === 'admin' });
  }

  @Get('by-hash/:hash')
  @UseGuards(OptionalJwtAuthGuard)
  byHash(@Param('hash') hash: string, @CurrentUser() u: AuthUser | undefined) {
    return this.recipes.byHash(hash, { includeHidden: u?.role === 'admin' });
  }

  @Get(':id')
  @UseGuards(OptionalJwtAuthGuard)
  get(@Param('id') id: string, @CurrentUser() u: AuthUser | undefined) {
    return this.recipes.get(id, { includeHidden: u?.role === 'admin' });
  }

  // ---------------------------------------------------------- Stage 2: own recipes
  @Post()
  @UseGuards(JwtAuthGuard)
  publish(@Body() dto: PublishRecipeDto, @CurrentUser() u: AuthUser) {
    return this.recipes.createByUser(u.id, {
      ofr: dto.ofr,
      imageUrls: dto.imageUrls,
    });
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard)
  update(
    @Param('id') id: string,
    @Body() dto: UpdateRecipeDto,
    @CurrentUser() u: AuthUser,
  ) {
    return this.recipes.updateOwn(id, u.id, dto.ofr);
  }

  @Delete(':id')
  @HttpCode(204)
  @UseGuards(JwtAuthGuard)
  remove(@Param('id') id: string, @CurrentUser() u: AuthUser) {
    return this.recipes.deleteOwn(id, u.id);
  }

  @Post(':id/images')
  @UseGuards(JwtAuthGuard)
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }),
  )
  async upload(
    @Param('id') id: string,
    @CurrentUser() u: AuthUser,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('file is required');
    await this.recipes.assertOwner(id, u.id);
    return this.images.uploadRecipeImage(id, {
      buffer: file.buffer,
      mimetype: file.mimetype,
    });
  }
}
