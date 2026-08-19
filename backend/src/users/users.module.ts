import { Module } from '@nestjs/common';
import { MeController } from './me.controller';
import { UsersService } from './users.service';

@Module({
  providers: [UsersService],
  controllers: [MeController],
  exports: [UsersService],
})
export class UsersModule {}
