import { useEffect, useRef, useState } from 'react';
import { useRecipe, useRecipeMutations, useReportMutations } from '../../api/admin';
import type { AdminRecipe } from '../../api/types';
import { Dots, Pill, ago, cx, useConfirm, useToast } from '../../ui';
import { statusOf } from './RecipeTable';

const SPEC: [string, string][] = [
  ['dynamic_range', 'DR'], ['white_balance', 'WB'], ['highlight', 'Highlight'], ['shadow', 'Shadow'], ['color', 'Color'], ['grain_roughness', 'Grain'],
  ['sharpness', 'Sharp'], ['high_iso_nr', 'NR'], ['clarity', 'Clarity'], ['color_chrome_effect', 'CC FX'], ['color_chrome_fx_blue', 'CC Blue'], ['exposure_compensation', 'Exp'],
];
const fmt = (v: unknown) => v === undefined || v === null ? '—' : typeof v === 'number' ? (v > 0 ? `+${v}` : String(v)) : String(v);

export function RecipePane({ id, onClose }: { id: string | null; onClose: () => void }) {
  const q = useRecipe(id);
  if (!id) return <aside className="pane blank"><div><div className="mono" style={{ marginBottom: 8 }}>NO SELECTION</div>Pick a kata on the left to review it.</div></aside>;
  if (q.isLoading || !q.data) return <aside className="pane blank"><Dots /></aside>;
  return <PaneBody r={q.data} onClose={onClose} key={q.data.id} />;
}

function PaneBody({ r, onClose }: { r: AdminRecipe; onClose: () => void }) {
  const { patch, upload, removeImage } = useRecipeMutations();
  const { resolve } = useReportMutations();
  const toast = useToast();
  const confirm = useConfirm();
  const file = useRef<HTMLInputElement>(null);
  const [edit, setEdit] = useState(false);
  const [name, setName] = useState(r.name);
  const [attr, setAttr] = useState(r.sourceAttribution ?? '');
  const [url, setUrl] = useState(r.sourceUrl ?? '');
  const [sensors, setSensors] = useState(r.sensors.join(', '));
  useEffect(() => { setName(r.name); setAttr(r.sourceAttribution ?? ''); setUrl(r.sourceUrl ?? ''); setSensors(r.sensors.join(', ')); }, [r]);

  const st = statusOf(r);
  const errors = r.issues.filter((i) => i.severity === 'error');
  const warnings = r.issues.filter((i) => i.severity === 'warning');
  const busy = patch.isPending || upload.isPending || removeImage.isPending;
  const act = (body: Parameters<typeof patch.mutate>[0]['body'], msg: string) =>
    patch.mutate({ id: r.id, body }, { onSuccess: () => toast(msg), onError: (e) => toast(e.message, true) });
  const save = () => act({ name: name.trim(), sourceAttribution: attr.trim(), sourceUrl: url.trim() || undefined, sensors: sensors.split(',').map((s) => s.trim()).filter(Boolean) }, 'Saved');

  return (
    <aside className="pane" aria-label={`Recipe ${r.name}`}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span className="mono">{r.author ? 'SUBMISSION' : 'CURATED'} · {ago(r.createdAt)} ago</span>
        <button className="btn sm secondary" onClick={onClose} aria-label="Close pane">✕</button>
      </div>

      <div className="frames">
        {r.imageUrls.map((u, i) => (
          <div className="frame" key={u}><img src={u} alt="" /><button className="x" aria-label="Remove image" onClick={() => removeImage.mutate({ id: r.id, index: i }, { onError: (e) => toast(e.message, true) })}>×</button></div>
        ))}
        {r.imageUrls.length < 3 && (
          <button className="frame add" onClick={() => file.current?.click()} disabled={busy}>{upload.isPending ? <Dots /> : '+ IMAGE'}</button>
        )}
        <input ref={file} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={(e) => { const f = e.target.files?.[0]; if (f) upload.mutate({ id: r.id, file: f }, { onSuccess: () => toast('Image uploaded'), onError: (err) => toast(err.message, true) }); e.target.value = ''; }} />
      </div>

      {!edit ? (
        <div>
          <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 10 }}>
            <div style={{ minWidth: 0 }}>
              <div className="display" style={{ fontSize: 18, lineHeight: 1.15 }}>{r.name}</div>
              <div className="sub muted" style={{ marginTop: 6, fontSize: 11.5 }}>
                {r.sourceAttribution ?? (r.author?.displayName ?? 'No attribution')}{r.sourceUrl && <> · <a href={r.sourceUrl} target="_blank" rel="noreferrer" className="dim" style={{ textDecoration: 'underline' }}>source ↗</a></>}
              </div>
              <div className="chips" style={{ marginTop: 8 }}>{r.sensors.map((s) => <span key={s} className="pill line">{s}</span>)}{r.isMono && <span className="pill dimmed">MONO</span>}</div>
            </div>
            <Pill kind={st.kind}>{st.label}</Pill>
          </div>
          <button className="btn sm secondary" style={{ marginTop: 10 }} onClick={() => setEdit(true)}>Edit details</button>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div className="field"><label htmlFor="f-name">Name</label><input id="f-name" value={name} onChange={(e) => setName(e.target.value)} maxLength={60} /></div>
          <div className="field"><label htmlFor="f-attr">Attribution</label><input id="f-attr" value={attr} onChange={(e) => setAttr(e.target.value)} maxLength={120} /></div>
          <div className="field"><label htmlFor="f-url">Source URL</label><input id="f-url" value={url} onChange={(e) => setUrl(e.target.value)} placeholder="https://" /></div>
          <div className="field"><label htmlFor="f-sens">Sensors (comma-separated)</label><input id="f-sens" value={sensors} onChange={(e) => setSensors(e.target.value)} /></div>
          <div className="rowbtn"><button className="btn sm primary" onClick={() => { save(); setEdit(false); }} disabled={busy}>Save</button><button className="btn sm secondary" onClick={() => setEdit(false)}>Cancel</button></div>
        </div>
      )}

      <hr className="hr" />
      <div>
        <div className="mono" style={{ marginBottom: 10 }}>VALIDATION</div>
        <div className="check">
          <div className={errors.length ? 'bad' : 'ok'}><i>{errors.length ? '!' : '✓'}</i><span>{errors.length ? `${errors.length} field${errors.length > 1 ? 's' : ''} out of range: ${errors.map((e) => e.field).join(', ')}` : `${r.fieldCount} fields in range for ${r.sensors[0] ?? 'this sensor'}`}</span></div>
          {warnings.map((w) => <div key={w.field + w.message} className="warn"><i>·</i><span>{w.field}: {w.message}</span></div>)}
          <div className={r.sourceUrl ? 'ok' : 'warn'}><i>{r.sourceUrl ? '✓' : '·'}</i><span>{r.sourceUrl ? 'Source URL present' : 'No source URL'}</span></div>
          <div className={r.sourceAttribution || r.author ? 'ok' : 'warn'}><i>{r.sourceAttribution || r.author ? '✓' : '·'}</i><span>{r.sourceAttribution ? `Attributed to ${r.sourceAttribution}` : r.author ? `By ${r.author.email}` : 'No attribution'}</span></div>
          {r.openReports > 0 && <div className="bad"><i>!</i><span>{r.openReports} open report{r.openReports > 1 ? 's' : ''}</span></div>}
        </div>
      </div>

      {r.reports && r.reports.length > 0 && (
        <div>
          <div className="mono" style={{ marginBottom: 10 }}>REPORTS</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {r.reports.map((rep) => (
              <div key={rep.id} className="card" style={{ padding: 10, display: 'flex', gap: 10, alignItems: 'center', opacity: rep.resolvedAt ? 0.55 : 1 }}>
                <div style={{ flex: 1, minWidth: 0 }}><div style={{ fontSize: 12 }}>{rep.reason}</div><div className="sub muted" style={{ fontSize: 10.5 }}>{rep.user.email} · {ago(rep.createdAt)} ago{rep.resolvedAt ? ' · resolved' : ''}</div></div>
                {!rep.resolvedAt && <button className="btn sm secondary" onClick={() => resolve.mutate({ id: rep.id, resolved: true }, { onSuccess: () => toast('Report resolved') })}>Resolve</button>}
              </div>
            ))}
          </div>
        </div>
      )}

      <div>
        <div className="mono" style={{ marginBottom: 10 }}>PAYLOAD · {r.filmSim}</div>
        <div className="spec">{SPEC.map(([k, l]) => <div key={k}><div className="k">{l}</div><div className="v">{fmt(r.ofr[k])}</div></div>)}</div>
        <details style={{ marginTop: 10 }}><summary className="mono" style={{ cursor: 'pointer' }}>OFR JSON · {r.hash.slice(0, 8)}</summary><pre className="payload" style={{ marginTop: 8 }}>{JSON.stringify(r.ofr, null, 1)}</pre></details>
      </div>

      <div className="actions">
        {!r.reviewed && !r.hidden && <button className="btn lg primary display" disabled={busy || errors.length > 0} onClick={() => act({ reviewed: true }, 'Approved')}>{busy ? <Dots /> : 'Approve'}</button>}
        {r.hidden ? (
          <button className="btn secondary" disabled={busy} onClick={() => act({ hidden: false }, 'Unhidden')}>Unhide</button>
        ) : (
          <button className="btn danger" disabled={busy} onClick={async () => { if (await confirm(`Hide "${r.name}" from the library?`)) act({ hidden: true }, 'Hidden'); }}>Hide from library</button>
        )}
        {r.reviewed && !r.hidden && <button className="btn secondary" disabled={busy} onClick={() => act({ reviewed: false }, 'Moved back to pending')}>Un-verify</button>}
        <span className={cx('mono')} style={{ textAlign: 'center', fontSize: 9 }}>{r.favouritesCount} favourites · updated {ago(r.updatedAt)} ago</span>
      </div>
    </aside>
  );
}
