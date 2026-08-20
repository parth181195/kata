import sharp from 'sharp';
import { createTestApp, signInAs } from './helpers/app';

const base = {
  v: 1,
  name: 'My Kata',
  sensors: ['X-Trans V'],
  film_simulation: 'Classic Chrome',
  dynamic_range: 'DR200',
  d_range_priority: 'Off',
  grain_roughness: 'Weak',
  white_balance: 'Daylight',
  white_balance_red: 1,
  white_balance_blue: -2,
  sharpness: 0,
  high_iso_nr: -2,
  clarity: 0,
};
type R = {
  id: string;
  name: string;
  hash: string;
  reviewed: boolean;
  authorId: string | null;
  favouritesCount: number;
  imageUrls: string[];
};
type Page<T> = { items: T[] };

describe('stage 2: user recipes + favourites', () => {
  it('publish / list / edit / delete with ownership; favourites; owner images', async () => {
    const t = await createTestApp();
    const { token: admin } = await signInAs(t, 'admin', { admin: true });
    const { token: a, id: aId } = await signInAs(t, 'alice');
    const { token: b } = await signInAs(t, 'bob');
    const as = (tok: string) => ({
      get: (p: string) => t.http.get(p).set('Authorization', `Bearer ${tok}`),
      post: (p: string) => t.http.post(p).set('Authorization', `Bearer ${tok}`),
      patch: (p: string) =>
        t.http.patch(p).set('Authorization', `Bearer ${tok}`),
      del: (p: string) =>
        t.http.delete(p).set('Authorization', `Bearer ${tok}`),
      put: (p: string) => t.http.put(p).set('Authorization', `Bearer ${tok}`),
    });
    const A = as(a),
      B = as(b),
      ADM = as(admin);

    // invalid → 400 with issues
    const bad = await A.post('/recipes')
      .send({ ofr: { ...base, clarity: 9 } })
      .expect(400);
    expect((bad.body as { issues: unknown[] }).issues.length).toBeGreaterThan(
      0,
    );

    // publish → public + pending in admin queue
    const r = (await A.post('/recipes').send({ ofr: base }).expect(201))
      .body as R;
    expect(r.reviewed).toBe(false);
    expect(r.authorId).toBe(aId);
    await B.get(`/recipes/${r.id}`).expect(200);
    const pub = (await B.get('/recipes').expect(200)).body as Page<R>;
    expect(pub.items.map((x) => x.id)).toContain(r.id);
    const queue = (await ADM.get('/admin/queue?tab=pending').expect(200))
      .body as Page<R>;
    expect(queue.items.map((x) => x.id)).toEqual([r.id]);

    // duplicate → 409 {id}
    const dup = await B.post('/recipes')
      .send({ ofr: { ...base, name: 'Copy' } })
      .expect(409);
    expect((dup.body as { id: string }).id).toBe(r.id);

    // ownership
    await B.patch(`/recipes/${r.id}`)
      .send({ ofr: { ...base, clarity: 1 } })
      .expect(403);
    await B.del(`/recipes/${r.id}`).expect(403);

    // admin approves; owner edits → hash changes + back to pending
    await ADM.patch(`/admin/recipes/${r.id}`)
      .send({ reviewed: true })
      .expect(200);
    const edited = (
      await A.patch(`/recipes/${r.id}`)
        .send({ ofr: { ...base, name: 'My Kata v2', clarity: 1 } })
        .expect(200)
    ).body as R;
    expect(edited.name).toBe('My Kata v2');
    expect(edited.hash).not.toBe(r.hash);
    expect(edited.reviewed).toBe(false);

    // mine
    const mine = (await A.get('/me/recipes').expect(200)).body as Page<R>;
    expect(mine.items.map((x) => x.id)).toEqual([r.id]);
    expect(
      ((await B.get('/me/recipes').expect(200)).body as Page<R>).items,
    ).toEqual([]);

    // favourites: idempotent put, count, list, delete
    await B.put(`/me/favourites/${r.id}`).expect(204);
    await B.put(`/me/favourites/${r.id}`).expect(204);
    await A.put(`/me/favourites/${r.id}`).expect(204);
    expect(
      ((await A.get(`/recipes/${r.id}`).expect(200)).body as R).favouritesCount,
    ).toBe(2);
    expect(
      ((await B.get('/me/favourites').expect(200)).body as { ids: string[] })
        .ids,
    ).toEqual([r.id]);
    await B.del(`/me/favourites/${r.id}`).expect(204);
    expect(
      ((await A.get(`/recipes/${r.id}`).expect(200)).body as R).favouritesCount,
    ).toBe(1);
    await B.put('/me/favourites/00000000-0000-4000-8000-000000000000').expect(
      404,
    );

    // owner images (≤3), non-owner 403
    const jpeg = await sharp({
      create: {
        width: 800,
        height: 600,
        channels: 3,
        background: { r: 20, g: 20, b: 20 },
      },
    })
      .jpeg()
      .toBuffer();
    await B.post(`/recipes/${r.id}/images`)
      .attach('file', jpeg, 'p.jpg')
      .expect(403);
    for (let i = 0; i < 3; i++)
      await A.post(`/recipes/${r.id}/images`)
        .attach('file', jpeg, 'p.jpg')
        .expect(201);
    await A.post(`/recipes/${r.id}/images`)
      .attach('file', jpeg, 'p.jpg')
      .expect(400);
    expect(
      ((await A.get(`/recipes/${r.id}`).expect(200)).body as R).imageUrls
        .length,
    ).toBe(3);

    // versions: publish = v1, edit = v2, list, revert → v3 with v1's settings
    const r2 = (
      await A.post('/recipes')
        .send({ ofr: { ...base, name: 'Versioned', clarity: 2 } })
        .expect(201)
    ).body as R & { version: number };
    expect(r2.version).toBe(1);
    const r2e = (
      await A.patch(`/recipes/${r2.id}`)
        .send({ ofr: { ...base, name: 'Versioned', clarity: 3 } })
        .expect(200)
    ).body as R & { version: number };
    expect(r2e.version).toBe(2);
    const vers = (await A.get(`/recipes/${r2.id}/versions`).expect(200))
      .body as { current: number; items: { version: number; name: string }[] };
    expect(vers.current).toBe(2);
    expect(vers.items.map((v) => v.version)).toEqual([2, 1]);
    await B.get(`/recipes/${r2.id}/versions`).expect(403);
    const reverted = (
      await A.post(`/recipes/${r2.id}/revert`).send({ version: 1 }).expect(201)
    ).body as R & { version: number; ofr: { clarity: number } };
    expect(reverted.version).toBe(3);
    expect(reverted.ofr.clarity).toBe(2);
    await A.del(`/recipes/${r2.id}`).expect(204);

    // handles: claim, normalise, conflict, appears on recipe DTOs
    const me = (
      await A.patch('/me').send({ handle: '@Parth.Test' }).expect(200)
    ).body as { handle: string };
    expect(me.handle).toBe('parth.test');
    await B.patch('/me').send({ handle: 'parth.test' }).expect(409);
    await B.patch('/me').send({ handle: 'x' }).expect(400);
    const r3 = (
      await A.post('/recipes')
        .send({ ofr: { ...base, name: 'Handled', clarity: 4 } })
        .expect(201)
    ).body as R;
    const got = (await B.get(`/recipes/${r3.id}`).expect(200)).body as R & {
      authorHandle: string;
      version: number;
    };
    expect(got.authorHandle).toBe('parth.test');
    await A.del(`/recipes/${r3.id}`).expect(204);

    // cameras: upsert per (model, firmware), seenCount increments; admin summary
    await A.put('/me/cameras')
      .send({
        model: 'X-S20',
        firmware: '3.30',
        pid: 0x02f7,
        slots: 4,
        props: 26,
      })
      .expect(204);
    await A.put('/me/cameras')
      .send({
        model: 'X-S20',
        firmware: '3.30',
        pid: 0x02f7,
        slots: 4,
        props: 26,
      })
      .expect(204);
    await B.put('/me/cameras')
      .send({ model: 'X-S20', firmware: '3.30', slots: 4 })
      .expect(204);
    await A.put('/me/cameras').send({ model: 'X-T5', slots: 7 }).expect(204);
    await A.put('/me/cameras').send({ model: 'X-T5', slots: 9 }).expect(400);
    const cams = (await A.get('/me/cameras').expect(200)).body as {
      items: { model: string; seenCount: number; firmware: string }[];
    };
    expect(cams.items.map((c) => [c.model, c.seenCount])).toEqual(
      expect.arrayContaining([
        ['X-S20', 2],
        ['X-T5', 1],
      ]),
    );
    const seen = (await ADM.get('/admin/cameras-seen').expect(200)).body as {
      items: { model: string; users: number; connections: number }[];
    };
    expect(seen.items.find((i) => i.model === 'X-S20')).toMatchObject({
      users: 2,
      connections: 3,
    });

    // delete own → gone everywhere
    await A.del(`/recipes/${r.id}`).expect(204);
    await B.get(`/recipes/${r.id}`).expect(404);
    await t.app.close();
  });
});
