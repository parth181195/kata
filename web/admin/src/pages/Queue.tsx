import { useMemo, useState } from 'react';
import { useQueue, useRecipeMutations, useStats } from '../api/admin';
import type { BulkAction, QueueTab } from '../api/types';
import { Chip, Dots, Empty, ago, useDebounced, useToast } from '../ui';
import { TopBar } from './Layout';
import { RecipePane } from './queue/RecipePane';
import { RecipeTable } from './queue/RecipeTable';

const TABS: { id: QueueTab; label: string; key: 'pending' | 'reported' | 'published' | 'hidden' }[] = [
  { id: 'pending', label: 'Pending', key: 'pending' }, { id: 'reported', label: 'Reported', key: 'reported' }, { id: 'published', label: 'Published', key: 'published' }, { id: 'hidden', label: 'Hidden', key: 'hidden' },
];
const SENSORS = ['X-Trans V', 'X-Trans IV', 'X-Trans III', 'X-Trans II', 'X-Trans I', 'GFX', 'Bayer'];

export function Queue({ mode = 'queue' }: { mode?: 'queue' | 'recipes' }) {
  const [tab, setTab] = useState<QueueTab>(mode === 'queue' ? 'pending' : 'all');
  const [q, setQ] = useState('');
  const [sensor, setSensor] = useState<string | undefined>();
  const dq = useDebounced(q);
  const stats = useStats();
  const filter = useMemo(() => ({ tab, q: dq || undefined, sensor }), [tab, dq, sensor]);
  const queue = useQueue(filter);
  const rows = useMemo(() => queue.data?.pages.flatMap((p) => p.items) ?? [], [queue.data]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [active, setActive] = useState<string | null>(null);
  const { bulk } = useRecipeMutations();
  const toast = useToast();
  const s = stats.data;
  const runBulk = (action: BulkAction) => bulk.mutate({ ids: [...selected], action }, { onSuccess: (r) => { toast(`${r.updated} updated`); setSelected(new Set()); }, onError: (e) => toast(e.message, true) });

  const sub = mode === 'queue' && s
    ? `${s.pending} submitted · ${s.openReports} reported${s.oldestPendingAt ? ` · oldest ${ago(s.oldestPendingAt)}` : ''}`
    : s ? `${s.recipes} recipes · ${s.published} live · ${s.hidden} hidden` : undefined;

  return (
    <>
      <TopBar title={mode === 'queue' ? 'Review queue' : 'Recipes'} sub={sub}>
        <label className="search"><span className="ring" /><input placeholder="Search recipes, creators, film sims" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search" /></label>
        <select value={sensor ?? ''} onChange={(e) => setSensor(e.target.value || undefined)} aria-label="Sensor filter" style={{ height: 36, borderRadius: 18 }}>
          <option value="">All sensors</option>{SENSORS.map((x) => <option key={x} value={x}>{x}</option>)}
        </select>
      </TopBar>
      <div className="content">
        <div className="scroll">
          {mode === 'queue' && s && (
            <div className="stats">
              <div className="stat"><span className="mono">Pending review</span><b>{s.pending}</b><span className="sub">{s.oldestPendingAt ? `oldest ${ago(s.oldestPendingAt)}` : 'queue is clear'}</span></div>
              <div className="stat"><span className="mono">Published katas</span><b>{s.published}</b><span className="sub">{s.recipes} total in the database</span></div>
              <div className={s.openReports ? 'stat red' : 'stat'}><span className="mono">Open reports</span><b>{s.openReports}</b><span className="sub">{s.reported} recipes flagged</span></div>
              <div className="stat"><span className="mono">Users</span><b>{s.users}</b><span className="sub">{s.hidden} hidden recipes</span></div>
            </div>
          )}
          <div className="tabs" role="tablist">
            {mode === 'recipes' && <Chip on={tab === 'all'} onClick={() => setTab('all')}>All{s ? ` ${s.recipes}` : ''}</Chip>}
            {TABS.map((t) => <Chip key={t.id} on={tab === t.id} onClick={() => { setTab(t.id); setSelected(new Set()); }}>{t.label}{s ? ` ${s[t.key]}` : ''}</Chip>)}
          </div>
          {queue.isLoading ? <div className="empty"><Dots /></div>
            : rows.length === 0 ? <Empty title={dq ? `No recipes for “${dq}”` : tab === 'pending' ? 'Queue is clear' : 'Nothing here'} body={tab === 'pending' && !dq ? 'New community submissions land here once Stage 2 publishing ships.' : undefined} />
            : <RecipeTable rows={rows} selected={selected} onSelect={setSelected} active={active} onOpen={setActive} />}
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span className="mono">Showing {rows.length}{queue.hasNextPage ? '+' : ''}</span>
            {queue.hasNextPage && <button className="btn sm secondary" onClick={() => void queue.fetchNextPage()} disabled={queue.isFetchingNextPage}>{queue.isFetchingNextPage ? <Dots /> : 'Load more'}</button>}
          </div>
          {selected.size > 0 && (
            <div className="bulk" role="toolbar" aria-label="Bulk actions">
              <span className="mono" style={{ color: '#000' }}>{selected.size} selected</span>
              <button className="btn sm primary" onClick={() => runBulk('approve')} disabled={bulk.isPending}>Approve</button>
              <button className="btn sm secondary" style={{ borderColor: '#000', color: '#000' }} onClick={() => runBulk('unhide')} disabled={bulk.isPending}>Unhide</button>
              <button className="btn sm danger" onClick={() => { if (window.confirm(`Hide ${selected.size} recipes?`)) runBulk('hide'); }} disabled={bulk.isPending}>Hide</button>
              <button className="btn sm" style={{ color: '#000' }} onClick={() => setSelected(new Set())}>Clear</button>
            </div>
          )}
        </div>
        <RecipePane id={active} onClose={() => setActive(null)} />
      </div>
    </>
  );
}
