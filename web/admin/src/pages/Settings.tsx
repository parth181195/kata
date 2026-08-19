import { API_BASE } from '../api/client';
import { useAuth } from '../auth/AuthProvider';
import { GOOGLE_CLIENT_ID } from '../auth/gis';
import { TopBar } from './Layout';

export function Settings() {
  const { user, signOut } = useAuth();
  return (
    <>
      <TopBar title="Settings" />
      <div className="content" style={{ gridTemplateColumns: '1fr' }}>
        <div className="scroll" style={{ maxWidth: 640 }}>
          <div className="card">
            <div className="mono" style={{ marginBottom: 10 }}>SESSION</div>
            <dl className="kv"><dt>Signed in as</dt><dd>{user?.email}</dd><dt>Role</dt><dd>{user?.role}</dd></dl>
            <button className="btn secondary" style={{ marginTop: 12 }} onClick={() => void signOut()}>Sign out</button>
          </div>
          <div className="card">
            <div className="mono" style={{ marginBottom: 10 }}>BUILD</div>
            <dl className="kv"><dt>API</dt><dd>{API_BASE}</dd><dt>Google client</dt><dd>{GOOGLE_CLIENT_ID ? `${GOOGLE_CLIENT_ID.slice(0, 14)}…` : 'not set'}</dd><dt>Version</dt><dd>{__APP_VERSION__}</dd></dl>
          </div>
          <div className="card soft">
            <div className="mono" style={{ marginBottom: 10 }}>OPS</div>
            <p className="muted" style={{ margin: 0, fontSize: 12 }}>Deploy with <code>web/deploy.sh --admin</code>. Promote an account from Creators. Library dumps: <code>backend/data/</code>. Runbook: <code>docs/ops/kata-api.md</code>.</p>
          </div>
        </div>
      </div>
    </>
  );
}
