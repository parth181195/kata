import { Injectable, UnauthorizedException } from '@nestjs/common';
import { OAuth2Client } from 'google-auth-library';
import { env } from '../config/env';
import { GoogleIdentity, GoogleVerifier } from './google-verifier';

@Injectable()
export class GoogleAuthLibraryVerifier extends GoogleVerifier {
  private readonly client = new OAuth2Client();

  async verify(idToken: string): Promise<GoogleIdentity> {
    const ticket = await this.client.verifyIdToken({
      idToken,
      audience: env.googleWebClientId || undefined,
    });
    const p = ticket.getPayload();
    if (!p?.sub || !p.email)
      throw new UnauthorizedException('Google token has no identity');
    return {
      sub: p.sub,
      email: p.email,
      name: p.name ?? p.email.split('@')[0],
      picture: p.picture,
    };
  }
}
