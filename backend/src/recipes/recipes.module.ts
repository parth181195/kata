import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ImagesModule } from '../images/images.module';
import { MeRecipesController } from './me-recipes.controller';
import { RecipesController } from './recipes.controller';
import { RecipesService } from './recipes.service';

@Module({
  imports: [AuthModule, ImagesModule],
  controllers: [RecipesController, MeRecipesController],
  providers: [RecipesService],
  exports: [RecipesService],
})
export class RecipesModule {}
