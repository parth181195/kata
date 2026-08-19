import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
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
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { ImagesService } from '../images/images.service';
import { RecipesService } from '../recipes/recipes.service';
import { AdminService } from './admin.service';
import { CAMERA_PROFILES } from './camera-profiles';
import { BulkDto } from './dto/bulk.dto';
import { CreateRecipeDto } from './dto/create-recipe.dto';
import { PatchRecipeDto } from './dto/patch-recipe.dto';
import { PatchReportDto, PatchUserDto } from './dto/patch-user.dto';
import { CursorDto, QueueDto, ReportsQueryDto } from './dto/queue.dto';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
export class AdminController {
  constructor(
    private readonly recipes: RecipesService,
    private readonly images: ImagesService,
    private readonly admin: AdminService,
  ) {}

  @Get('ping')
  ping() {
    return { ok: true };
  }

  @Get('stats')
  stats() {
    return this.admin.stats();
  }

  @Get('camera-profiles')
  cameraProfiles() {
    return CAMERA_PROFILES;
  }

  @Get('cameras-seen')
  camerasSeen() {
    return this.admin.camerasSeen();
  }

  // ---------------------------------------------------------- recipes
  @Get('queue')
  queue(@Query() dto: QueueDto) {
    return this.admin.queue(dto);
  }

  @Get('recipes/:id')
  recipe(@Param('id') id: string) {
    return this.admin.recipe(id);
  }

  @Patch('recipes/:id')
  patchRecipe(
    @Param('id') id: string,
    @Body() dto: PatchRecipeDto,
    @CurrentUser() u: AuthUser,
  ) {
    return this.admin.patchRecipe(id, dto, u.id);
  }

  @Post('recipes/bulk')
  bulk(@Body() dto: BulkDto, @CurrentUser() u: AuthUser) {
    return this.admin.bulk(dto.ids, dto.action, u.id);
  }

  @Delete('recipes/:id/images/:index')
  removeImage(
    @Param('id') id: string,
    @Param('index', ParseIntPipe) index: number,
  ) {
    return this.admin.removeImage(id, index);
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

  // ---------------------------------------------------------- users
  @Get('users')
  users(@Query() dto: CursorDto) {
    return this.admin.users(dto);
  }

  @Patch('users/:id')
  patchUser(
    @Param('id') id: string,
    @Body() dto: PatchUserDto,
    @CurrentUser() u: AuthUser,
  ) {
    return this.admin.patchUser(id, dto.role, u.id);
  }

  // ---------------------------------------------------------- reports
  @Get('reports')
  reports(@Query() dto: ReportsQueryDto) {
    return this.admin.reports(dto);
  }

  @Patch('reports/:id')
  patchReport(
    @Param('id') id: string,
    @Body() dto: PatchReportDto,
    @CurrentUser() u: AuthUser,
  ) {
    return this.admin.patchReport(id, dto.resolved, u.id);
  }
}
