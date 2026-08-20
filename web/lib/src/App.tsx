import { useEffect, useRef } from 'react';
import { Navigate, NavLink, Outlet, Route, Routes } from 'react-router';
import { useAuth } from './AuthProvider';
import { GOOGLE_CLIENT_ID, loadGis } from './gis';
import { Editor, Library, Mine, RecipePage } from './pages';
import { Dots } from './ui';

function SignInWall() {
  const { signInWithCredential, error } = useAuth();
  const slot = useRef<HTMLDivElement>(null);
  useEffect(() => {
    let live = true;
    loadGis().then(() => {
      if (!live || !slot.current || !window.google) return;
      window.google.accounts.id.initialize({ client_id: GOOGLE_CLIENT_ID, callback: (r) => void signInWithCredential(r.credential), ux_mode: 'popup' });
      window.google.accounts.id.renderButton(slot.current, { theme: 'filled_black', size: 'large', shape: 'pill', text: 'continue_with', width: 280 });
    }).catch(() => {});
    return () => { live = false; };
  }, [signInWithCredential]);
  return (
    <div className="wall">
      <div className="box">
        <span className="mark">型</span>
        <h1>The Library</h1>
        <p>342 film-simulation recipes with real sample frames. Sign in with Google to browse, save and publish — it keeps your katas with you across the app and the web.</p>
        <div className="gsi" ref={slot} aria-label="Sign in with Google" />
        {error && <p style={{ color: 'var(--red)' }}>{error}</p>}
        <p style={{ fontSize: 11 }}><a href="/" style={{ color: 'var(--muted)', textDecoration: 'underline' }}>About Kata</a> · <a href="/privacy.html" style={{ color: 'var(--muted)', textDecoration: 'underline' }}>Privacy</a></p>
      </div>
    </div>
  );
}

function Shell() {
  const { user, signOut } = useAuth();
  return (
    <>
      <header className="hd">
        <div className="wrap">
          <a className="brand" href="/">Kata 型</a>
          <nav style={{ display: 'flex', gap: 16, fontSize: 12.5 }}>
            <NavLink to="/library" end style={({ isActive }) => ({ color: isActive ? 'var(--fg)' : 'var(--muted)' })}>Library</NavLink>
            <NavLink to="/library/mine" style={({ isActive }) => ({ color: isActive ? 'var(--fg)' : 'var(--muted)' })}>Mine</NavLink>
          </nav>
          <span className="grow" />
          <a className="getapp" href="/kata.apk">Get the app</a>
          {user && (
            <button type="button" title={`${user.email} — sign out`} onClick={() => { if (confirm('Sign out?')) void signOut(); }} style={{ border: 0, background: 'none', padding: 0, cursor: 'pointer' }}>
              {user.photoUrl ? <img className="avatar" src={user.photoUrl} alt="" referrerPolicy="no-referrer" /> : <span className="avatar">{user.displayName.slice(0, 2).toUpperCase()}</span>}
            </button>
          )}
        </div>
      </header>
      <Outlet />
    </>
  );
}

export default function App() {
  const { status } = useAuth();
  if (status === 'booting') return <div className="wall"><Dots /></div>;
  return (
    <Routes>
      <Route element={<Shell />}>
        {status === 'signedOut' ? (
          <Route path="*" element={<SignInWall />} />
        ) : (
          <>
            <Route path="/library" element={<Library />} />
            <Route path="/library/mine" element={<Mine />} />
            <Route path="/library/new" element={<Editor />} />
            <Route path="/library/edit/:id" element={<Editor />} />
            <Route path="/r/:id" element={<RecipePage />} />
            <Route path="*" element={<Navigate to="/library" replace />} />
          </>
        )}
      </Route>
    </Routes>
  );
}
