import { BunnyClient } from '../../src/images/bunny.client';

export class FakeBunnyClient extends BunnyClient {
  uploads: { path: string; bytes: number; contentType: string }[] = [];
  lastBuffers: Buffer[] = [];
  put(path: string, body: Buffer, contentType: string): Promise<string> {
    this.uploads.push({ path, bytes: body.length, contentType });
    this.lastBuffers.push(body);
    return Promise.resolve(`https://cdn.test/${path}`);
  }
}
