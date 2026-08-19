import { GoogleIdentity, GoogleVerifier } from '../../src/auth/google-verifier';

export class FakeGoogleVerifier extends GoogleVerifier {
  tokens = new Map<string, GoogleIdentity>();
  add(token: string, id: GoogleIdentity) {
    this.tokens.set(token, id);
    return this;
  }
  verify(idToken: string): Promise<GoogleIdentity> {
    const id = this.tokens.get(idToken);
    if (!id) return Promise.reject(new Error('invalid token'));
    return Promise.resolve(id);
  }
}
