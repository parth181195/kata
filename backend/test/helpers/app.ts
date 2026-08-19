import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import type { App } from 'supertest/types';
import { AppModule } from '../../src/app.module';
import { corsOptions } from '../../src/config/cors';
import { GoogleVerifier } from '../../src/auth/google-verifier';
import { BunnyClient } from '../../src/images/bunny.client';
import { PrismaService } from '../../src/prisma/prisma.service';
import { FakeBunnyClient } from './fake-bunny';
import { FakeGoogleVerifier } from './fake-google';

export async function resetDb(prisma: PrismaService) {
  await prisma.$executeRawUnsafe(
    'TRUNCATE "user_cameras","reports","favourites","refresh_tokens","recipes","users" RESTART IDENTITY CASCADE',
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
  app.enableCors(corsOptions);
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

/** Signs in a fake Google identity; optionally promotes to admin. Returns the access token. */
export async function signInAs(
  t: Awaited<ReturnType<typeof createTestApp>>,
  key: string,
  opts: { admin?: boolean; email?: string; name?: string } = {},
): Promise<{ token: string; id: string }> {
  const sub = `g-${key}`;
  t.google.add(`fake-google-id-token-${key}`, {
    sub,
    email: opts.email ?? `${key}@example.com`,
    name: opts.name ?? key,
  });
  if (opts.admin) {
    await t.http
      .post('/auth/google')
      .send({ idToken: `fake-google-id-token-${key}` });
    await t.prisma.user.update({
      where: { googleSub: sub },
      data: { role: 'admin' },
    });
  }
  const res = await t.http
    .post('/auth/google')
    .send({ idToken: `fake-google-id-token-${key}` });
  const body = res.body as { accessToken: string; user: { id: string } };
  return { token: body.accessToken, id: body.user.id };
}
