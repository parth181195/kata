import { NavLink, Outlet } from 'react-router';
import { useStats } from '../api/admin';
import { useAuth } from '../auth/AuthProvider';
import { Avatar, cx } from '../ui';

const NAV: { to: string; label: string; count?: (s: { pending: number; openReports: number }) => number; red?: boolean }[] = [
  { to: '/', label: 'Review queue', count: (s) => s.pending },
  { to: '/recipes', label: 'Recipes' },
  { to: '/creators', label: 'Creators' },
  { to: '/reports', label: 'Reports', count: (s) => s.openReports, red: true },
  { to: '/cameras', label: 'Camera profiles' },
  { to: '/settings', label: 'Settings' },
];

export function Layout() {
  const { user } = useAuth();
  const stats = useStats();
  return (
    <div className="shell">
      <aside className="side">
        <div className="brand"><span className="mark">型</span><span className="word">Kata<small>ADMIN</small></span></div>
        <nav className="nav" aria-label="Sections">
          {NAV.map((n) => {
            const c = n.count && stats.data ? n.count(stats.data) : 0;
            return (
              <NavLink key={n.to} to={n.to} end={n.to === '/'} className={({ isActive }) => cx(isActive && 'active')}>
                <span>{n.label}</span>
                {c > 0 && <span className={cx('count', n.red && 'red')}>{c}</span>}
              </NavLink>
            );
          })}
        </nav>
        <div className="spacer" />
        {stats.data && (
          <div className="card soft" style={{ padding: 12 }}>
            <div className="mono" style={{ fontSize: 9 }}>LIBRARY</div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, fontFamily: 'var(--mono)', fontSize: 12 }}>
              <span>{stats.data.published} <span className="muted">live</span></span>
              <span>{stats.data.hidden} <span className="muted">hidden</span></span>
              <span>{stats.data.users} <span className="muted">users</span></span>
            </div>
          </div>
        )}
        {user && (
          <div className="me">
            <Avatar url={user.photoUrl} name={user.displayName} />
            <div className="who"><b>{user.displayName}</b><span>{user.email}</span></div>
          </div>
        )}
      </aside>
      <div className="main"><Outlet /></div>
    </div>
  );
}

export function TopBar({ title, sub, children }: { title: string; sub?: string; children?: React.ReactNode }) {
  return (
    <header className="topbar">
      <h1>{title}</h1>
      {sub && <span className="sub">{sub}</span>}
      <span className="grow" />
      {children}
    </header>
  );
}
