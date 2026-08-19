import { useMemo, useState } from 'react';
import { useReportMutations, useReports } from '../api/admin';
import { Chip, Dots, Empty, Pill, ago, useToast } from '../ui';
import { TopBar } from './Layout';
import { RecipePane } from './queue/RecipePane';

export function Reports() {
  const [status, setStatus] = useState<'open' | 'resolved' | 'all'>('open');
  const reports = useReports(status);
  const rows = useMemo(() => reports.data?.pages.flatMap((p) => p.items) ?? [], [reports.data]);
  const { resolve } = useReportMutations();
  const [active, setActive] = useState<string | null>(null);
  const toast = useToast();
  return (
    <>
      <TopBar title="Reports" sub={`${rows.length}${reports.hasNextPage ? '+' : ''} ${status}`} />
      <div className="content">
        <div className="scroll">
          <div className="tabs">{(['open', 'resolved', 'all'] as const).map((s) => <Chip key={s} on={status === s} onClick={() => setStatus(s)}>{s}</Chip>)}</div>
          {reports.isLoading ? <div className="empty"><Dots /></div> : rows.length === 0 ? <Empty glyph="✓" title={status === 'open' ? 'No open reports' : 'Nothing here'} body="Reports filed from the app land here." /> : (
            <div className="table" style={{ gridTemplateColumns: 'minmax(200px,1.4fr) minmax(220px,2fr) minmax(140px,1fr) 100px 140px' }}>
              <div className="th">Recipe</div><div className="th">Reason</div><div className="th">Reported by</div><div className="th">When</div><div className="th">Actions</div>
              {rows.map((r) => (
                <div key={r.id} style={{ display: 'contents' }} className={active === r.recipe.id ? 'row-act' : undefined}>
                  <div className="td" onClick={() => setActive(r.recipe.id)} style={{ cursor: 'pointer' }}><div style={{ minWidth: 0 }}><div className="name">{r.recipe.name}</div><div className="sub">{r.recipe.filmSim}{r.recipe.hidden ? ' · hidden' : ''}</div></div></div>
                  <div className="td wrap" style={{ fontSize: 12 }}>{r.reason}</div>
                  <div className="td"><div style={{ minWidth: 0 }}><div style={{ fontSize: 12 }}>{r.user.displayName}</div><div className="sub">{r.user.email}</div></div></div>
                  <div className="td sub">{ago(r.createdAt)} ago</div>
                  <div className="td">{r.resolvedAt ? <Pill kind="dimmed">RESOLVED</Pill> : <button className="btn sm primary" disabled={resolve.isPending} onClick={() => resolve.mutate({ id: r.id, resolved: true }, { onSuccess: () => toast('Resolved'), onError: (e) => toast(e.message, true) })}>Resolve</button>}</div>
                </div>
              ))}
            </div>
          )}
          {reports.hasNextPage && <button className="btn sm secondary" style={{ alignSelf: 'flex-start' }} onClick={() => void reports.fetchNextPage()}>Load more</button>}
        </div>
        <RecipePane id={active} onClose={() => setActive(null)} />
      </div>
    </>
  );
}
