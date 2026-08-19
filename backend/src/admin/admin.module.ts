import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ImagesModule } from '../images/images.module';
import { RecipesModule } from '../recipes/recipes.module';
import { ReportsController } from '../recipes/reports.controller';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

@Module({
  imports: [AuthModule, RecipesModule, ImagesModule],
  controllers: [AdminController, ReportsController],
  providers: [AdminService],
  exports: [AdminService],
})
export class AdminModule {}
