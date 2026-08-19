export interface GoogleIdentity {
  sub: string;
  email: string;
  name: string;
  picture?: string;
}

/** Verifies a Google ID token. Real implementation uses google-auth-library; tests use a fake. */
export abstract class GoogleVerifier {
  abstract verify(idToken: string): Promise<GoogleIdentity>;
}
