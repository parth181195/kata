import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ImagesModule } from '../images/images.module';
import { RecipesModule } from '../recipes/recipes.module';
import { AdminController } from './admin.controller';

@Module({
  imports: [AuthModule, RecipesModule, ImagesModule],
  controllers: [AdminController],
})
export class AdminModule {}
