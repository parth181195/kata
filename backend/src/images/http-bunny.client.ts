import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { env } from '../config/env';
import { BunnyClient } from './bunny.client';

@Injectable()
export class HttpBunnyClient extends BunnyClient {
  async put(path: string, body: Buffer, contentType: string): Promise<string> {
    const url = `https://${env.bunny.host}/${env.bunny.zone}/${path}`;
    const res = await fetch(url, {
      method: 'PUT',
      headers: { AccessKey: env.bunny.key, 'Content-Type': contentType },
      body: new Uint8Array(body),
    });
    if (!res.ok)
      throw new InternalServerErrorException(
        `Bunny upload failed: ${res.status}`,
      );
    return `https://${env.bunny.pullZoneHost}/${path}`;
  }
}
