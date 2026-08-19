import { createTestApp } from './helpers/app';

describe('health', () => {
  it('GET /health', async () => {
    const { app, http } = await createTestApp();
    const res = await http.get('/health').expect(200);
    expect((res.body as { ok: boolean }).ok).toBe(true);
    await app.close();
  });
});
