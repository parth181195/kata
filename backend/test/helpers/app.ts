import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import type { App } from 'supertest/types';
import { AppModule } from '../../src/app.module';
import { GoogleVerifier } from '../../src/auth/google-verifier';
import { BunnyClient } from '../../src/images/bunny.client';
import { PrismaService } from '../../src/prisma/prisma.service';
import { FakeBunnyClient } from './fake-bunny';
import { FakeGoogleVerifier } from './fake-google';

export async function resetDb(prisma: PrismaService) {
  await prisma.$executeRawUnsafe(
    'TRUNCATE "reports","favourites","refresh_tokens","recipes","users" RESTART IDENTITY CASCADE',
  );
}

/** Boots the full app against kata_test with fake Google/Bunny. */
export async function createTestApp() {
  const google = new FakeGoogleVerifier();
  const bunny = new FakeBunnyClient();
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(GoogleVerifier)
    .useValue(google)
    .overrideProvider(BunnyClient)
    .useValue(bunny)
    .compile();
  const app: INestApplication = moduleRef.createNestApplication();
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  await app.init();
  const prisma = app.get(PrismaService);
  await resetDb(prisma);
  return {
    app,
    prisma,
    http: request(app.getHttpServer() as App),
    google,
    bunny,
  };
}
