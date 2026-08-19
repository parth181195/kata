import { createTestApp, signInAs } from './helpers/app';

const base = {
  v: 1,
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
type Page<T> = { items: T[]; nextCursor: string | null };
type R = {
  id: string;
  name: string;
  reviewed: boolean;
  hidden: boolean;
  fieldCount: number;
  issues: unknown[];
  openReports: number;
};

describe('admin', () => {
  it('guards, stats, queue tabs, patch, bulk, reports, users, camera profiles', async () => {
    const t = await createTestApp();
    const { token: admin, id: adminId } = await signInAs(t, 'admin', {
      admin: true,
    });
    const { token: user, id: userId } = await signInAs(t, 'user');
    const A = (p: string) =>
      t.http.get(p).set('Authorization', `Bearer ${admin}`);

    await t.http
      .get('/admin/stats')
      .set('Authorization', `Bearer ${user}`)
      .expect(403);
    await t.http.get('/admin/stats').expect(401);

    // seed: one published, one pending, one hidden
    // distinct `highlight` per recipe so the settings hashes differ
    const mk = async (
      name: string,
      highlight: number,
      extra: Record<string, unknown>,
    ) =>
      (
        await t.http
          .post('/admin/recipes')
          .set('Authorization', `Bearer ${admin}`)
          .send({ ofr: { ...base, name, highlight }, ...extra })
          .expect(201)
      ).body as { id: string };
    const pub = await mk('Published One', 1, { reviewed: true });
    const pend = await mk('Pending One', 2, { reviewed: false });
    const hid = await mk('Hidden One', 3, { reviewed: true, hidden: true });

    const stats = (await A('/admin/stats').expect(200)).body as Record<
      string,
      number
    >;
    expect(stats).toMatchObject({
      pending: 1,
      published: 1,
      hidden: 1,
      reported: 0,
      users: 2,
      recipes: 3,
      openReports: 0,
    });

    const ids = async (tab: string) =>
      (
        (await A(`/admin/queue?tab=${tab}`).expect(200)).body as Page<R>
      ).items.map((r) => r.id);
    expect(await ids('pending')).toEqual([pend.id]);
    expect(await ids('published')).toEqual([pub.id]);
    expect(await ids('hidden')).toEqual([hid.id]);
    expect((await ids('all')).sort()).toEqual([pub.id, pend.id, hid.id].sort());
    const q = (await A('/admin/queue?tab=all&q=pending').expect(200))
      .body as Page<R>;
    expect(q.items.map((r) => r.name)).toEqual(['Pending One']);
    expect(q.items[0].fieldCount).toBe(11); // 10 base settings + highlight
    expect(q.items[0].issues).toEqual([]);

    // approve via PATCH, edit name
    const patched = (
      await t.http
        .patch(`/admin/recipes/${pend.id}`)
        .set('Authorization', `Bearer ${admin}`)
        .send({
          reviewed: true,
          name: 'Pending Approved',
          sourceAttribution: 'Tester',
        })
        .expect(200)
    ).body as R & { ofr: { name: string; source_attribution: string } };
    expect(patched.reviewed).toBe(true);
    expect(patched.name).toBe('Pending Approved');
    expect(patched.ofr.name).toBe('Pending Approved');
    expect(patched.ofr.source_attribution).toBe('Tester');
    expect(await ids('pending')).toEqual([]);

    // bulk hide both published → hidden tab has 3
    await t.http
      .post('/admin/recipes/bulk')
      .set('Authorization', `Bearer ${admin}`)
      .send({ ids: [pub.id, pend.id], action: 'hide' })
      .expect(201)
      .expect(({ body }) =>
        expect((body as { updated: number }).updated).toBe(2),
      );
    expect((await ids('hidden')).length).toBe(3);
    await t.http
      .post('/admin/recipes/bulk')
      .set('Authorization', `Bearer ${admin}`)
      .send({ ids: [pub.id, pend.id], action: 'unhide' })
      .expect(201);

    // user cannot see /recipes/:id for hidden; user reports the published one
    await t.http
      .get(`/recipes/${hid.id}`)
      .set('Authorization', `Bearer ${user}`)
      .expect(404);
    await t.http
      .post(`/recipes/${pub.id}/report`)
      .set('Authorization', `Bearer ${user}`)
      .send({ reason: 'wrong attribution' })
      .expect(201)
      .expect(({ body }) =>
        expect((body as { duplicate: boolean }).duplicate).toBe(false),
      );
    await t.http
      .post(`/recipes/${pub.id}/report`)
      .set('Authorization', `Bearer ${user}`)
      .send({ reason: 'again' })
      .expect(201)
      .expect(({ body }) =>
        expect((body as { duplicate: boolean }).duplicate).toBe(true),
      );
    await t.http
      .post(`/recipes/${pub.id}/report`)
      .set('Authorization', `Bearer ${user}`)
      .send({ reason: 'x' })
      .expect(400);
    expect(await ids('reported')).toEqual([pub.id]);
    const rep = (await A('/admin/reports?status=open').expect(200))
      .body as Page<{
      id: string;
      recipe: { id: string };
      user: { id: string };
    }>;
    expect(rep.items.length).toBe(1);
    expect(rep.items[0].recipe.id).toBe(pub.id);
    expect(rep.items[0].user.id).toBe(userId);
    const detail = (await A(`/admin/recipes/${pub.id}`).expect(200))
      .body as R & { reports: unknown[] };
    expect(detail.openReports).toBe(1);
    expect(detail.reports.length).toBe(1);
    await t.http
      .patch(`/admin/reports/${rep.items[0].id}`)
      .set('Authorization', `Bearer ${admin}`)
      .send({ resolved: true })
      .expect(200);
    expect(await ids('reported')).toEqual([]);
    expect(
      (
        (await A('/admin/reports?status=open').expect(200))
          .body as Page<unknown>
      ).items.length,
    ).toBe(0);
    expect(
      (
        (await A('/admin/reports?status=resolved').expect(200))
          .body as Page<unknown>
      ).items.length,
    ).toBe(1);

    // users + roles
    const users = (await A('/admin/users').expect(200)).body as Page<{
      id: string;
      role: string;
      recipeCount: number;
    }>;
    expect(users.items.length).toBe(2);
    await t.http
      .patch(`/admin/users/${adminId}`)
      .set('Authorization', `Bearer ${admin}`)
      .send({ role: 'user' })
      .expect(400);
    const promoted = (
      await t.http
        .patch(`/admin/users/${userId}`)
        .set('Authorization', `Bearer ${admin}`)
        .send({ role: 'admin' })
        .expect(200)
    ).body as { role: string };
    expect(promoted.role).toBe('admin');
    await t.http
      .patch(`/admin/users/${userId}`)
      .set('Authorization', `Bearer ${admin}`)
      .send({ role: 'user' })
      .expect(200);

    // images: remove index out of range → 400
    await t.http
      .delete(`/admin/recipes/${pub.id}/images/0`)
      .set('Authorization', `Bearer ${admin}`)
      .expect(400);

    const profiles = (await A('/admin/camera-profiles').expect(200)).body as {
      generations: unknown[];
    };
    expect(profiles.generations.length).toBeGreaterThanOrEqual(4);

    // CORS preflight for the admin origin
    await t.http
      .options('/admin/stats')
      .set('Origin', 'https://admin.kata.parthjansari.dev')
      .set('Access-Control-Request-Method', 'GET')
      .expect(204)
      .expect(
        'access-control-allow-origin',
        'https://admin.kata.parthjansari.dev',
      );
    await t.app.close();
  });
});
