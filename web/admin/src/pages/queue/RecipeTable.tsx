import type { AdminRecipe } from '../../api/types';
import { Avatar, Checkbox, Pill, Thumb, cx, sensorShort } from '../../ui';

export function statusOf(r: AdminRecipe): { label: string; kind: 'solid' | 'line' | 'dimmed' | 'red' } {
  if (r.issues.some((i) => i.severity === 'error')) return { label: `${r.issues.filter((i) => i.severity === 'error').length} INVALID`, kind: 'red' };
  if (r.hidden) return { label: 'HIDDEN', kind: 'dimmed' };
  if (r.openReports > 0) return { label: `${r.openReports} REPORTED`, kind: 'red' };
  if (r.reviewed) return { label: 'VERIFIED', kind: 'solid' };
  return { label: 'PENDING', kind: 'line' };
}

export function RecipeTable({ rows, selected, onSelect, active, onOpen, selectable = true }: {
  rows: AdminRecipe[]; selected: Set<string>; onSelect: (ids: Set<string>) => void; active: string | null; onOpen: (id: string) => void; selectable?: boolean;
}) {
  const allOn = rows.length > 0 && rows.every((r) => selected.has(r.id));
  const cols = selectable ? '36px minmax(240px,2fr) minmax(150px,1.2fr) 150px 76px 130px' : 'minmax(240px,2fr) minmax(150px,1.2fr) 150px 76px 130px';
  return (
    <div className="table" role="table" style={{ gridTemplateColumns: cols }}>
      {selectable && <div className="th" role="columnheader"><Checkbox on={allOn} onChange={(v) => onSelect(v ? new Set(rows.map((r) => r.id)) : new Set())} label="select all" /></div>}
      <div className="th" role="columnheader">Kata</div>
      <div className="th" role="columnheader">Creator</div>
      <div className="th" role="columnheader">Sensor</div>
      <div className="th" role="columnheader">Fields</div>
      <div className="th" role="columnheader">Status</div>
      {rows.map((r) => {
        const st = statusOf(r);
        const isSel = selected.has(r.id);
        const rowCls = cx(isSel && 'row-sel', active === r.id && 'row-act');
        const open = () => onOpen(r.id);
        const dr = (r.ofr.dynamic_range as string | undefined) ?? '';
        return (
          <div key={r.id} className={rowCls} role="row" style={{ display: 'contents' }}>
            {selectable && <div className="td" role="cell"><Checkbox on={isSel} onChange={(v) => { const n = new Set(selected); if (v) n.add(r.id); else n.delete(r.id); onSelect(n); }} label={`select ${r.name}`} /></div>}
            <div className="td" role="cell" onClick={open} style={{ cursor: 'pointer' }}>
              <Thumb url={r.imageUrls[0]} />
              <div style={{ minWidth: 0 }}><div className="name">{r.name}</div><div className="sub">{r.filmSim}{dr ? ` · ${dr}` : ''}</div></div>
            </div>
            <div className="td" role="cell" onClick={open} style={{ cursor: 'pointer' }}>
              {r.author ? <><Avatar url={r.author.photoUrl} name={r.author.displayName} size={22} /><span className="sub" style={{ color: 'var(--dim)' }}>{r.author.displayName}</span></> : <span className="sub">{r.sourceAttribution ?? 'Curated'}</span>}
            </div>
            <div className="td" role="cell" onClick={open} style={{ cursor: 'pointer', gap: 4 }}>
              {r.sensors.slice(0, 2).map((s) => <span key={s} className="pill line" style={{ height: 20 }}>{sensorShort(s)}</span>)}
              {r.sensors.length > 2 && <span className="sub">+{r.sensors.length - 2}</span>}
            </div>
            <div className="td" role="cell" onClick={open} style={{ cursor: 'pointer', fontFamily: 'var(--mono)', fontSize: 11.5 }}>
              <span className={cx(r.issues.some((i) => i.severity === 'error') && 'red')}>{r.fieldCount}/22</span>
            </div>
            <div className="td" role="cell" onClick={open} style={{ cursor: 'pointer' }}><Pill kind={st.kind}>{st.label}</Pill></div>
          </div>
        );
      })}
    </div>
  );
}
