import { useEffect, useRef, useState } from 'react';
import { useAuth } from './AuthProvider';
import { GOOGLE_CLIENT_ID, loadGis } from './gis';

export function SignIn() {
  const { signInWithCredential, error } = useAuth();
  const slot = useRef<HTMLDivElement>(null);
  const [gisError, setGisError] = useState<string | null>(null);
  useEffect(() => {
    let live = true;
    if (!GOOGLE_CLIENT_ID) { setGisError('VITE_GOOGLE_WEB_CLIENT_ID is not set for this build'); return; }
    loadGis().then(() => {
      if (!live || !slot.current || !window.google) return;
      window.google.accounts.id.initialize({ client_id: GOOGLE_CLIENT_ID, callback: (r) => void signInWithCredential(r.credential), ux_mode: 'popup' });
      window.google.accounts.id.renderButton(slot.current, { theme: 'filled_black', size: 'large', shape: 'pill', text: 'continue_with', width: 280 });
    }).catch((e: Error) => setGisError(e.message));
    return () => { live = false; };
  }, [signInWithCredential]);
  return (
    <div className="auth">
      <div className="box">
        <span className="mark">型</span>
        <h1>KATA ADMIN</h1>
        <p>Curators only. Sign in with the Google account that has the admin role.</p>
        <div className="gsi" ref={slot} aria-label="Sign in with Google" />
        {(error || gisError) && <p className="red">{error ?? gisError}</p>}
      </div>
    </div>
  );
}

export function NotAdmin() {
  const { user, signOut } = useAuth();
  return (
    <div className="auth">
      <div className="box">
        <span className="mark">型</span>
        <h1>NOT AN ADMIN</h1>
        <p>{user?.email} is signed in but doesn't have the admin role. Ask the owner to promote you, then sign in again.</p>
        <button className="btn secondary" onClick={() => void signOut()}>Sign out</button>
      </div>
    </div>
  );
}
