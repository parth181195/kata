import { createTestApp } from './helpers/app';

type Tokens = {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  user: { email: string; role: string };
};

describe('auth', () => {
  it('google sign-in, /me, refresh rotation, reuse detection, logout, admin guard', async () => {
    const { app, http, prisma, google } = await createTestApp();
    google.add('fake-google-id-token-1', {
      sub: 'g-1',
      email: 'parth@example.com',
      name: 'Parth',
      picture: 'https://p/1.png',
    });

    await http
      .post('/auth/google')
      .send({ idToken: 'definitely-not-a-valid-google-token' })
      .expect(401);
    const signIn = await http
      .post('/auth/google')
      .send({ idToken: 'fake-google-id-token-1' })
      .expect(200);
    const t = signIn.body as Tokens;
    expect(t.user.email).toBe('parth@example.com');
    expect(t.user.role).toBe('user');
    expect(t.expiresIn).toBe(900);

    await http.get('/me').expect(401);
    const me = await http
      .get('/me')
      .set('Authorization', `Bearer ${t.accessToken}`)
      .expect(200);
    expect((me.body as { email: string }).email).toBe('parth@example.com');

    // rotation
    const r1 = (
      await http
        .post('/auth/refresh')
        .send({ refreshToken: t.refreshToken })
        .expect(200)
    ).body as Tokens;
    expect(r1.refreshToken).not.toBe(t.refreshToken);
    // reuse of the rotated token → 401 and revokes the whole family
    await http
      .post('/auth/refresh')
      .send({ refreshToken: t.refreshToken })
      .expect(401);
    await http
      .post('/auth/refresh')
      .send({ refreshToken: r1.refreshToken })
      .expect(401);

    // fresh sign-in, logout, then refresh fails
    const s2 = (
      await http
        .post('/auth/google')
        .send({ idToken: 'fake-google-id-token-1' })
        .expect(200)
    ).body as Tokens;
    await http
      .post('/auth/logout')
      .send({ refreshToken: s2.refreshToken })
      .expect(204);
    await http
      .post('/auth/refresh')
      .send({ refreshToken: s2.refreshToken })
      .expect(401);

    // admin guard
    const s3 = (
      await http
        .post('/auth/google')
        .send({ idToken: 'fake-google-id-token-1' })
        .expect(200)
    ).body as Tokens;
    await http
      .get('/admin/ping')
      .set('Authorization', `Bearer ${s3.accessToken}`)
      .expect(403);
    await prisma.user.update({
      where: { googleSub: 'g-1' },
      data: { role: 'admin' },
    });
    const s4 = (
      await http
        .post('/auth/google')
        .send({ idToken: 'fake-google-id-token-1' })
        .expect(200)
    ).body as Tokens;
    expect(s4.user.role).toBe('admin');
    await http
      .get('/admin/ping')
      .set('Authorization', `Bearer ${s4.accessToken}`)
      .expect(200);

    await app.close();
  });
});
