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
import { ImagesService } from '../images/images.service';
import { ListRecipesDto } from './dto/list-recipes.dto';
import {
  PublishRecipeDto,
  RevertDto,
  UpdateRecipeDto,
} from './dto/user-recipe.dto';
import { RecipesService } from './recipes.service';

@Controller('recipes')
@UseGuards(JwtAuthGuard)
export class RecipesController {
  constructor(
    private readonly recipes: RecipesService,
    private readonly images: ImagesService,
  ) {}

  // Sign-in is required to browse (user decision 2026-08-20) — the class guard covers reads too.
  //
  // Hidden recipes stay out of the feed for *everyone*, admins included: hiding is a
  // moderation decision, and the admin console has its own "hidden" tab (GET /admin/queue)
  // for working through them. An admin browsing the library should see the library.
  @Get()
  list(@Query() dto: ListRecipesDto) {
    return this.recipes.list(dto, { includeHidden: false });
  }

  @Get('by-hash/:hash')
  byHash(@Param('hash') hash: string, @CurrentUser() u: AuthUser) {
    return this.recipes.byHash(hash, { includeHidden: u.role === 'admin' });
  }

  @Get(':id')
  get(@Param('id') id: string, @CurrentUser() u: AuthUser) {
    return this.recipes.get(id, { includeHidden: u.role === 'admin' });
  }

  // ---------------------------------------------------------- Stage 2: own recipes
  @Post()
  publish(@Body() dto: PublishRecipeDto, @CurrentUser() u: AuthUser) {
    return this.recipes.createByUser(u.id, {
      ofr: dto.ofr,
      imageUrls: dto.imageUrls,
    });
  }

  @Patch(':id')
  update(
    @Param('id') id: string,
    @Body() dto: UpdateRecipeDto,
    @CurrentUser() u: AuthUser,
  ) {
    return this.recipes.updateOwn(id, u.id, dto.ofr);
  }

  @Delete(':id')
  @HttpCode(204)
  remove(@Param('id') id: string, @CurrentUser() u: AuthUser) {
    return this.recipes.deleteOwn(id, u.id);
  }

  // ---------------------------------------------------------- versions (design 5a: keeps the last 10)
  @Get(':id/versions')
  versions(@Param('id') id: string, @CurrentUser() u: AuthUser) {
    return this.recipes.versions(id, u.id, u.role === 'admin');
  }

  @Post(':id/revert')
  revert(
    @Param('id') id: string,
    @Body() dto: RevertDto,
    @CurrentUser() u: AuthUser,
  ) {
    return this.recipes.revert(id, u.id, dto.version);
  }

  @Post(':id/images')
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
