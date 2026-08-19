import { useMemo, useState } from 'react';
import { useUserMutations, useUsers } from '../api/admin';
import { useAuth } from '../auth/AuthProvider';
import { Avatar, Dots, Empty, Pill, ago, useDebounced, useToast } from '../ui';
import { TopBar } from './Layout';

export function Creators() {
  const [q, setQ] = useState('');
  const dq = useDebounced(q);
  const users = useUsers(dq || undefined);
  const rows = useMemo(() => users.data?.pages.flatMap((p) => p.items) ?? [], [users.data]);
  const { role } = useUserMutations();
  const { user: me } = useAuth();
  const toast = useToast();
  return (
    <>
      <TopBar title="Creators" sub={`${rows.length}${users.hasNextPage ? '+' : ''} accounts`}>
        <label className="search"><span className="ring" /><input placeholder="Search by email or name" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search users" /></label>
      </TopBar>
      <div className="content" style={{ gridTemplateColumns: '1fr' }}>
        <div className="scroll">
          {users.isLoading ? <div className="empty"><Dots /></div> : rows.length === 0 ? <Empty title="No accounts" /> : (
            <div className="table" style={{ gridTemplateColumns: 'minmax(240px,2fr) 110px 90px 90px 120px 160px' }}>
              <div className="th">Account</div><div className="th">Role</div><div className="th">Recipes</div><div className="th">Reports</div><div className="th">Joined</div><div className="th">Actions</div>
              {rows.map((u) => (
                <div key={u.id} style={{ display: 'contents' }}>
                  <div className="td"><Avatar url={u.photoUrl} name={u.displayName} /><div style={{ minWidth: 0 }}><div style={{ fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis' }}>{u.displayName}{u.id === me?.id && <span className="muted"> · you</span>}</div><div className="sub">{u.email}</div></div></div>
                  <div className="td">{u.role === 'admin' ? <Pill kind="solid">ADMIN</Pill> : <Pill kind="dimmed" hollow>USER</Pill>}</div>
                  <div className="td" style={{ fontFamily: 'var(--mono)' }}>{u.recipeCount}</div>
                  <div className="td" style={{ fontFamily: 'var(--mono)' }}>{u.reportCount}</div>
                  <div className="td sub">{ago(u.createdAt)} ago</div>
                  <div className="td">
                    {u.id !== me?.id && (
                      <button className="btn sm secondary" disabled={role.isPending} onClick={() => {
                        const next = u.role === 'admin' ? 'user' : 'admin';
                        if (window.confirm(`${next === 'admin' ? 'Promote' : 'Demote'} ${u.email} to ${next}?`)) role.mutate({ id: u.id, role: next }, { onSuccess: () => toast(`${u.email} is now ${next}`), onError: (e) => toast(e.message, true) });
                      }}>{u.role === 'admin' ? 'Make user' : 'Make admin'}</button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
          {users.hasNextPage && <button className="btn sm secondary" style={{ alignSelf: 'flex-start' }} onClick={() => void users.fetchNextPage()}>Load more</button>}
        </div>
      </div>
    </>
  );
}
