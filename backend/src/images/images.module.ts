import { Module } from '@nestjs/common';
import { BunnyClient } from './bunny.client';
import { HttpBunnyClient } from './http-bunny.client';
import { ImagesService } from './images.service';

@Module({
  providers: [
    ImagesService,
    { provide: BunnyClient, useClass: HttpBunnyClient },
  ],
  exports: [ImagesService],
})
export class ImagesModule {}
