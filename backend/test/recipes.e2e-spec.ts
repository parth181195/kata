import { createTestApp } from './helpers/app';

type Tokens = { accessToken: string };
type RecipeDto = {
  id: string;
  hash: string;
  name: string;
  filmSim: string;
  isMono: boolean;
  hidden: boolean;
  sensors: string[];
};
type Page = { items: RecipeDto[]; nextCursor: string | null };

const kodachrome = {
  v: 1,
  name: 'Kodachrome 64',
  sensors: ['X-Trans IV'],
  source_attribution: 'Fuji X Weekly',
  film_simulation: 'Classic Chrome',
  dynamic_range: 'DR400',
  d_range_priority: 'Off',
  grain_roughness: 'Weak',
  grain_size: 'Small',
  color_chrome_effect: 'Weak',
  color_chrome_fx_blue: 'Off',
  white_balance: 'Daylight',
  white_balance_red: 2,
  white_balance_blue: -5,
  highlight: -1,
  shadow: 0.5,
  color: 2,
  sharpness: -2,
  high_iso_nr: -4,
  clarity: 0,
};
const mono = {
  v: 1,
  name: 'Mono Push',
  sensors: ['X-Trans V'],
  film_simulation: 'Acros Red',
  dynamic_range: 'DR200',
  d_range_priority: 'Off',
  grain_roughness: 'Strong',
  grain_size: 'Large',
  white_balance: 'Auto',
  white_balance_red: 2,
  white_balance_blue: -3,
  highlight: 2,
  shadow: 3,
  sharpness: 2,
  high_iso_nr: -2,
  clarity: -2,
  monochromatic_color_warm_cool: 2,
  monochromatic_color_magenta_green: -1,
};
const velvia = {
  ...kodachrome,
  name: 'Slide Film',
  film_simulation: 'Velvia',
  color: 4,
  sensors: ['GFX'],
};

describe('recipes', () => {
  it('list/filter/search/paginate, get, by-hash, admin create', async () => {
    const { app, http, prisma, google } = await createTestApp();
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
      .send({ idToken: 'fake-google-id-token-admin' })
      .expect(200);
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
    const A = { Authorization: `Bearer ${admin}` };
    const U = { Authorization: `Bearer ${user}` };

    // create (admin only, validated)
    await http
      .post('/admin/recipes')
      .set(U)
      .send({ ofr: kodachrome })
      .expect(403);
    const bad = await http
      .post('/admin/recipes')
      .set(A)
      .send({ ofr: { ...kodachrome, clarity: 9 } })
      .expect(400);
    expect((bad.body as { issues: { field: string }[] }).issues[0].field).toBe(
      'clarity',
    );
    const k = (
      await http
        .post('/admin/recipes')
        .set(A)
        .send({ ofr: kodachrome, reviewed: true })
        .expect(201)
    ).body as RecipeDto;
    expect(k.hash).toBe(
      'ac98f45967554208ac8fd9b485c3b6598beb99f9fd17b941843fff4c0c3ec176',
    );
    expect(k.filmSim).toBe('Classic Chrome');
    await http
      .post('/admin/recipes')
      .set(A)
      .send({ ofr: kodachrome })
      .expect(409);
    const m = (
      await http.post('/admin/recipes').set(A).send({ ofr: mono }).expect(201)
    ).body as RecipeDto;
    expect(m.isMono).toBe(true);
    const h = (
      await http
        .post('/admin/recipes')
        .set(A)
        .send({ ofr: velvia, hidden: true })
        .expect(201)
    ).body as RecipeDto;

    // list as user: hidden excluded, newest first
    const all = (await http.get('/recipes').set(U).expect(200)).body as Page;
    expect(all.items.map((r) => r.name)).toEqual([
      'Mono Push',
      'Kodachrome 64',
    ]);
    expect(all.nextCursor).toBeNull();
    // admin sees hidden
    expect(
      ((await http.get('/recipes').set(A)).body as Page).items.length,
    ).toBe(3);
    // filters
    expect(
      ((await http.get('/recipes?mono=true').set(U)).body as Page).items.map(
        (r) => r.name,
      ),
    ).toEqual(['Mono Push']);
    expect(
      (
        (await http.get('/recipes?verified=true').set(U)).body as Page
      ).items.map((r) => r.name),
    ).toEqual(['Kodachrome 64']);
    expect(
      (
        (await http.get('/recipes?sensor=X-Trans%20V').set(U)).body as Page
      ).items.map((r) => r.name),
    ).toEqual(['Mono Push']);
    expect(
      (
        (await http.get('/recipes?filmSim=Classic%20Chrome').set(U))
          .body as Page
      ).items.map((r) => r.name),
    ).toEqual(['Kodachrome 64']);
    expect(
      ((await http.get('/recipes?q=koda').set(U)).body as Page).items.map(
        (r) => r.name,
      ),
    ).toEqual(['Kodachrome 64']);
    expect(
      ((await http.get('/recipes?q=acros').set(U)).body as Page).items.map(
        (r) => r.name,
      ),
    ).toEqual(['Mono Push']);
    // pagination
    const p1 = (await http.get('/recipes?limit=1').set(U)).body as Page;
    expect(p1.items.length).toBe(1);
    expect(p1.nextCursor).not.toBeNull();
    const p2 = (
      await http
        .get(`/recipes?limit=1&cursor=${encodeURIComponent(p1.nextCursor!)}`)
        .set(U)
    ).body as Page;
    expect(p2.items[0].name).toBe('Kodachrome 64');
    expect(p2.nextCursor).toBeNull();
    // get / by-hash / hidden
    await http.get(`/recipes/${k.id}`).set(U).expect(200);
    await http.get(`/recipes/${h.id}`).set(U).expect(404);
    await http.get(`/recipes/${h.id}`).set(A).expect(200);
    await http.get(`/recipes/by-hash/${k.hash}`).set(U).expect(200);
    await http.get('/recipes/by-hash/nope').set(U).expect(404);
    // sign-in required everywhere (user decision): anonymous reads are 401
    await http.get('/recipes').expect(401);
    await http.get(`/recipes/${k.id}`).expect(401);
    await http.post('/recipes').send({ ofr: {} }).expect(401);

    await app.close();
  });
});
