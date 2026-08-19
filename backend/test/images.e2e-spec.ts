import sharp from 'sharp';
import { createTestApp } from './helpers/app';

type Tokens = { accessToken: string };
type RecipeDto = { id: string; imageUrls: string[] };

const ofr = {
  v: 1,
  name: 'Img Test',
  sensors: ['X-Trans V'],
  film_simulation: 'Provia',
  dynamic_range: 'DR100',
  d_range_priority: 'Off',
  grain_roughness: 'Off',
  white_balance: 'Auto',
  white_balance_red: 0,
  white_balance_blue: 0,
  sharpness: 0,
  high_iso_nr: 0,
  clarity: 0,
};

describe('images', () => {
  it('admin uploads a JPEG → resized main + thumb to Bunny, url stored on recipe', async () => {
    const { app, http, prisma, google, bunny } = await createTestApp();
    google.add('fake-google-id-token-admin', {
      sub: 'g-admin',
      email: 'admin@example.com',
      name: 'Admin',
    });
    google.add('fake-google-id-token-user', {
      sub: 'g-user',
      email: 'user@example.com',
      name: 'User',
    });
    await http
      .post('/auth/google')
      .send({ idToken: 'fake-google-id-token-admin' });
    await prisma.user.update({
      where: { googleSub: 'g-admin' },
      data: { role: 'admin' },
    });
    const admin = (
      (
        await http
          .post('/auth/google')
          .send({ idToken: 'fake-google-id-token-admin' })
      ).body as Tokens
    ).accessToken;
    const user = (
      (
        await http
          .post('/auth/google')
          .send({ idToken: 'fake-google-id-token-user' })
      ).body as Tokens
    ).accessToken;

    const r = (
      await http
        .post('/admin/recipes')
        .set('Authorization', `Bearer ${admin}`)
        .send({ ofr })
        .expect(201)
    ).body as RecipeDto;
    const jpeg = await sharp({
      create: {
        width: 2400,
        height: 1600,
        channels: 3,
        background: { r: 40, g: 40, b: 40 },
      },
    })
      .jpeg()
      .toBuffer();

    await http
      .post(`/admin/recipes/${r.id}/images`)
      .set('Authorization', `Bearer ${user}`)
      .attach('file', jpeg, 'p.jpg')
      .expect(403);
    await http
      .post(`/admin/recipes/${r.id}/images`)
      .set('Authorization', `Bearer ${admin}`)
      .attach('file', Buffer.from('not an image'), 'x.txt')
      .expect(400);
    const res = await http
      .post(`/admin/recipes/${r.id}/images`)
      .set('Authorization', `Bearer ${admin}`)
      .attach('file', jpeg, 'p.jpg')
      .expect(201);
    const body = res.body as { url: string; thumbUrl: string };
    expect(body.url).toMatch(/^https:\/\/cdn\.test\/recipes\/.+\.jpg$/);
    expect(body.thumbUrl).toMatch(/_t\.jpg$/);
    expect(bunny.uploads.length).toBe(2);
    expect(bunny.uploads.every((u) => u.contentType === 'image/jpeg')).toBe(
      true,
    );
    const main = bunny.uploads.find((u) => !u.path.endsWith('_t.jpg'))!;
    const thumb = bunny.uploads.find((u) => u.path.endsWith('_t.jpg'))!;
    expect(main.bytes).toBeGreaterThan(thumb.bytes);
    expect(bunny.lastBuffers.length).toBe(2);
    expect((await sharp(bunny.lastBuffers[0]).metadata()).width).toBe(1600); // resized from 2400 on the long edge
    expect((await sharp(bunny.lastBuffers[1]).metadata()).width).toBe(400);

    const updated = await prisma.recipe.findUnique({ where: { id: r.id } });
    expect(updated!.imageUrls).toEqual([body.url]);
    await app.close();
  });
});
