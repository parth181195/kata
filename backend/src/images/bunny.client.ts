/** Uploads a file to Bunny Storage and returns its public CDN URL. */
export abstract class BunnyClient {
  abstract put(
    path: string,
    body: Buffer,
    contentType: string,
  ): Promise<string>;
}
