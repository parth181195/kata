import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { RecipesModule } from '../recipes/recipes.module';
import { AdminController } from './admin.controller';

@Module({
  imports: [AuthModule, RecipesModule],
  controllers: [AdminController],
})
export class AdminModule {}
