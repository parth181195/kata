import { useEffect, useRef } from 'react';
import { Navigate, NavLink, Outlet, Route, Routes, useLocation, useNavigate, useSearchParams } from 'react-router';
import { useAuth } from './AuthProvider';
import { GOOGLE_CLIENT_ID, loadGis } from './gis';
import { Editor, Library, Mine, RecipePage, Settings } from './pages';
import { Dots } from './ui';

// design 1f — the web variant of the first-run screen (sign-in is required on the web)
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
        <div>
          <h1>Kata</h1>
          <div className="tag" style={{ marginTop: 8 }}>The library · on the web</div>
        </div>
        <p>342 film-simulation recipes with real frames, your saved katas, publishing and version history. Writing to the camera lives in the apps — this is everything else.</p>
        <div className="gsi" ref={slot} aria-label="Sign in with Google" />
        {error && <p style={{ color: 'var(--red)' }}>{error}</p>}
        <p style={{ fontSize: 11 }}><a href="/" style={{ color: 'var(--muted)', textDecoration: 'underline' }}>About Kata</a> · <a href="/privacy" style={{ color: 'var(--muted)', textDecoration: 'underline' }}>Privacy</a> · <a href="/kata.apk" style={{ color: 'var(--muted)', textDecoration: 'underline' }}>Get the app</a></p>
      </div>
    </div>
  );
}

function Shell() {
  const { user } = useAuth();
  const loc = useLocation();
  const nav = useNavigate();
  const [params] = useSearchParams();
  const ctx = loc.pathname.startsWith('/library/mine') ? 'MINE' : loc.pathname.startsWith('/library/settings') ? 'SETTINGS' : loc.pathname.startsWith('/library/saved') ? 'SAVED' : loc.pathname.startsWith('/library/new') || loc.pathname.startsWith('/library/edit') ? 'EDITOR' : 'LIBRARY';
  return (
    <>
      <header className="top">
        <a className="brand" href="/">Kata <span style={{ fontWeight: 400 }}>型</span></a>
        <span className="ctx">{ctx}</span>
        <span className="grow" />
        <a className="getapp" href="/kata.apk">Get the app</a>
        {user && (
          <button type="button" title={user.email} onClick={() => nav('/library/settings')} style={{ border: 0, background: 'none', padding: 0, cursor: 'pointer' }}>
            {user.photoUrl ? <img className="avatar" src={user.photoUrl} alt="" referrerPolicy="no-referrer" /> : <span className="avatar">{user.displayName.slice(0, 2).toUpperCase()}</span>}
          </button>
        )}
      </header>
      <div className="frame">
        <nav className="side" aria-label="Sections">
          <NavLink to="/library" end className={({ isActive }) => (isActive && !params.get('saved') ? 'on' : '')}>Library</NavLink>
          <NavLink to="/library/saved" className={({ isActive }) => (isActive ? 'on' : '')}>Saved</NavLink>
          <NavLink to="/library/mine" className={({ isActive }) => (isActive ? 'on' : '')}>Mine</NavLink>
          <NavLink to="/library/new" className={({ isActive }) => (isActive ? 'on' : '')}>New kata</NavLink>
          <div className="sect">App</div>
          <NavLink to="/library/settings" className={({ isActive }) => (isActive ? 'on' : '')}>Settings</NavLink>
          <a href="/#faq">Help &amp; FAQ</a>
        </nav>
        <Outlet />
      </div>
    </>
  );
}

export default function App() {
  const { status } = useAuth();
  if (status === 'booting') return <div className="wall"><Dots /></div>;
  if (status === 'signedOut') {
    return (
      <>
        <header className="top"><a className="brand" href="/">Kata <span style={{ fontWeight: 400 }}>型</span></a><span className="grow" /><a className="getapp" href="/kata.apk">Get the app</a></header>
        <SignInWall />
      </>
    );
  }
  return (
    <Routes>
      <Route element={<Shell />}>
        <Route path="/library" element={<Library />} />
        <Route path="/library/saved" element={<Library mode="saved" />} />
        <Route path="/library/mine" element={<Mine />} />
        <Route path="/library/new" element={<Editor />} />
        <Route path="/library/edit/:id" element={<Editor />} />
        <Route path="/library/settings" element={<Settings />} />
        <Route path="/r/:id" element={<RecipePage />} />
        <Route path="*" element={<Navigate to="/library" replace />} />
      </Route>
    </Routes>
  );
}
