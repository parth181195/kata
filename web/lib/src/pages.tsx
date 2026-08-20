import QRCode from 'qrcode';
import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router';
import { specSummary, useDelete, useFavourites, useMine, usePublish, useRecipe, useRecipes, useReport, useToggleFavourite, PublishConflict, PublishInvalid, type Filter, type OfrIssue } from './api';
import { useAuth } from './AuthProvider';
import { encodeKataCode } from './kataCode';
import type { Ofr, RecipeDto } from './types';
import { Chip, Dots, Swatch, useToast } from './ui';

export const FILMS = ['Provia', 'Velvia', 'Astia', 'Classic Chrome', 'Pro Neg. Hi', 'Pro Neg. Std', 'Classic Negative', 'Eterna', 'Eterna Bleach Bypass', 'Nostalgic Negative', 'Reala Ace', 'Acros STD', 'Acros Yellow', 'Acros Red', 'Acros Green', 'Monochrome STD', 'Monochrome Yellow', 'Monochrome Red', 'Monochrome Green', 'Sepia'];
export const MONO = new Set(FILMS.slice(11));
const SENSORS = ['X-Trans V', 'X-Trans IV', 'X-Trans III', 'GFX', 'Bayer'];

// ---------------------------------------------------------------- library (1g: cards left, detail pane right)
export function Library({ mode = 'library' }: { mode?: 'library' | 'saved' }) {
  const [params, setParams] = useSearchParams();
  const sel = params.get('r');
  const [q, setQ] = useState('');
  const [dq, setDq] = useState('');
  const [f, setF] = useState<Filter>({ sort: 'newest' });
  useEffect(() => { const t = setTimeout(() => setDq(q), 250); return () => clearTimeout(t); }, [q]);
  const filter = useMemo(() => ({ ...f, q: dq || undefined }), [f, dq]);
  const recipes = useRecipes(filter);
  const favs = useFavourites();
  let rows = recipes.data?.pages.flatMap((p) => p.items) ?? [];
  if (mode === 'saved') rows = rows.filter((r) => favs.data?.has(r.id));
  const active = rows.find((r) => r.id === sel) ?? rows[0];
  return (
    <div className="content">
      <div className="list">
        <div className="bar">
          <label className="search"><input placeholder={`Search recipes, film sims, authors`} value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search" /></label>
          <button type="button" className="chip" onClick={() => setF((x) => ({ ...x, sort: x.sort === 'newest' ? 'popular' : 'newest' }))}>{f.sort === 'newest' ? 'Newest' : 'Most saved'} ▾</button>
          <Chip on={!!f.verified} onClick={() => setF((x) => ({ ...x, verified: x.verified ? undefined : true }))}>Verified</Chip>
          {SENSORS.slice(0, 2).map((s) => <Chip key={s} on={f.sensor === s} onClick={() => setF((x) => ({ ...x, sensor: x.sensor === s ? undefined : s }))}>{s}</Chip>)}
          <Chip on={f.mono === true} onClick={() => setF((x) => ({ ...x, mono: x.mono ? undefined : true }))}>B&amp;W</Chip>
        </div>
        {recipes.isLoading || (mode === 'saved' && favs.isLoading) ? <div className="empty"><Dots /></div> : rows.length === 0 ? <div className="empty">{mode === 'saved' ? 'Nothing saved yet — hit ♡ on any kata.' : 'No katas match.'}</div> : (
          <div className="cards">
            {rows.map((r) => (
              <button key={r.id} type="button" className={active?.id === r.id ? 'card on' : 'card'} onClick={() => setParams((p) => { p.set('r', r.id); return p; }, { replace: true })}>
                <span className="ph">{r.imageUrls[0] && <img src={r.imageUrls[0]} alt="" loading="lazy" />}{r.reviewed && <span className="ver">✓</span>}</span>
                <span className="meta"><span className="name">{r.name}</span><span className="sub">{r.filmSim} · {(r.ofr.dynamic_range as string) ?? '—'}</span></span>
              </button>
            ))}
          </div>
        )}
        {recipes.hasNextPage && <div style={{ marginTop: 14 }}><button type="button" className="btn secondary" onClick={() => void recipes.fetchNextPage()}>{recipes.isFetchingNextPage ? <Dots /> : 'Load more'}</button></div>}
      </div>
      <aside className="pane">{active ? <DetailPane r={active} /> : null}</aside>
    </div>
  );
}

// filter facets used by the shell sidebar
export function useLibraryFacets() { return { films: FILMS }; }

// ---------------------------------------------------------------- detail pane
const SPEC: [string, string][] = [
  ['film_simulation', 'Film sim'], ['dynamic_range', 'DR'], ['d_range_priority', 'DR priority'], ['white_balance', 'WB'], ['wb_kelvin', 'Kelvin'],
  ['white_balance_red', 'WB shift R'], ['white_balance_blue', 'WB shift B'], ['highlight', 'Highlight'], ['shadow', 'Shadow'], ['color', 'Color'],
  ['sharpness', 'Sharpness'], ['high_iso_nr', 'High ISO NR'], ['clarity', 'Clarity'], ['grain_roughness', 'Grain'], ['grain_size', 'Grain size'],
  ['color_chrome_effect', 'CC'], ['color_chrome_fx_blue', 'CC blue'], ['monochromatic_color_warm_cool', 'Warm/cool'], ['monochromatic_color_magenta_green', 'Mg/green'],
];
const fmt = (v: unknown) => (v == null ? '—' : typeof v === 'number' && v > 0 ? `+${v}` : String(v));

export function DetailPane({ r }: { r: RecipeDto }) {
  const nav = useNavigate();
  const { user } = useAuth();
  const favs = useFavourites();
  const toggle = useToggleFavourite();
  const report = useReport();
  const del = useDelete();
  const toast = useToast();
  const [qr, setQr] = useState<string>();
  const payload = useMemo(() => encodeKataCode(r.ofr, r.authorHandle ? `@${r.authorHandle}` : undefined), [r]);
  useEffect(() => {
    let live = true;
    QRCode.toDataURL(payload, { errorCorrectionLevel: 'M', margin: 4, width: 184 }).then((d) => { if (live) setQr(d); }).catch(() => {});
    return () => { live = false; };
  }, [payload]);
  const fav = favs.data?.has(r.id) ?? false;
  const own = user && r.authorId === user.id;
  return (
    <div className="dp">
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 10 }}>
        {r.reviewed && <span className="pill solid">Verified</span>}
        {own && <span className="pill">{r.reviewed ? 'Yours' : 'Yours · in review'}</span>}
        {r.sensors.map((s) => <span key={s} className="pill">{s}</span>)}
        <span className="pill">V{r.version}</span>
      </div>
      <h1>{r.name}</h1>
      <div className="credit">
        {r.authorHandle ? `@${r.authorHandle}` : (r.sourceAttribution ?? 'Community')}
        {r.sourceUrl && <> — <a href={r.sourceUrl} target="_blank" rel="noreferrer">{new URL(r.sourceUrl).hostname} ↗</a></>}
      </div>
      {r.imageUrls[0] && <div className="hero"><img src={r.imageUrls[0]} alt={r.name} /></div>}
      {r.imageUrls.length > 1 && <div className="thumbs">{r.imageUrls.slice(1, 3).map((u) => <img key={u} src={u} alt="" loading="lazy" />)}</div>}
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', margin: '0 0 14px' }}>
        <button type="button" className="btn secondary" onClick={() => toggle.mutate({ id: r.id, on: !fav })}>{fav ? '♥ Saved' : '♡ Save'}</button>
        <button type="button" className="btn secondary" onClick={() => nav(`/library/new?from=${r.id}`)}>Duplicate to edit</button>
        {own && <button type="button" className="btn secondary" onClick={() => nav(`/library/edit/${r.id}`)}>Edit</button>}
        {own && <button type="button" className="btn danger" onClick={() => { if (confirm(`Unpublish “${r.name}”?`)) del.mutate(r.id, { onSuccess: () => toast('Unpublished') }); }}>Unpublish</button>}
        {!own && <button type="button" className="btn secondary" onClick={() => { const reason = prompt('What’s wrong with this kata?'); if (reason) report.mutate({ id: r.id, reason }, { onSuccess: () => toast('Sent to the curators') }); }}>Report</button>}
      </div>
      <div className="specs">
        {SPEC.filter(([k]) => (r.ofr as Record<string, unknown>)[k] != null).map(([k, label]) => (
          <div key={k}><div className="k">{label}</div><div className="v">{fmt((r.ofr as Record<string, unknown>)[k])}</div></div>
        ))}
        <div><div className="k">Fingerprint</div><div className="v"><Swatch ofr={r.ofr} /></div></div>
      </div>
      <div className="codebox">
        {qr && <img src={qr} alt="Kata Code" />}
        <div style={{ minWidth: 0 }}>
          <div style={{ font: '800 12px/1.2 var(--display)', textTransform: 'uppercase', marginBottom: 5 }}>Kata Code · {payload.length} bytes</div>
          <div className="pay">{payload}</div>
          <div style={{ marginTop: 8, display: 'flex', gap: 8 }}>
            <button type="button" className="btn secondary" style={{ height: 28, fontSize: 11 }} onClick={() => { void navigator.clipboard.writeText(payload); toast('Kata Code copied'); }}>Copy code</button>
            <button type="button" className="btn secondary" style={{ height: 28, fontSize: 11 }} onClick={() => { void navigator.clipboard.writeText(`${location.origin}/r/${r.id}`); toast('Link copied'); }}>Copy link</button>
          </div>
        </div>
      </div>
      <div className="appnote"><b style={{ color: 'var(--fg)' }}>Write to camera</b> — writing into C1–C7 happens over USB in the Kata app (Android now, desktop soon). Scan the code with the app or <a href="/kata.apk">get it here</a>.</div>
    </div>
  );
}

/** /r/:id — standalone share-link page (same pane, full width). */
export function RecipePage() {
  const { id } = useParams();
  const q = useRecipe(id);
  if (q.isLoading) return <div className="list"><div className="empty"><Dots /></div></div>;
  if (!q.data) return <div className="list"><div className="empty">This kata doesn't exist (or was unpublished).</div></div>;
  return <div className="list" style={{ maxWidth: 560, margin: '0 auto' }}><DetailPane r={q.data} /></div>;
}

// ---------------------------------------------------------------- Mine (1h table)
export function Mine() {
  const nav = useNavigate();
  const mine = useMine();
  const [tab, setTab] = useState<'all' | 'published' | 'review'>('all');
  const rows = (mine.data?.items ?? []).filter((r) => tab === 'all' ? true : tab === 'published' ? r.reviewed : !r.reviewed);
  const all = mine.data?.items ?? [];
  return (
    <div className="content">
      <div className="list">
        <div className="bar">
          <Chip on={tab === 'all'} onClick={() => setTab('all')}>All {all.length}</Chip>
          <Chip on={tab === 'published'} onClick={() => setTab('published')}>Verified {all.filter((r) => r.reviewed).length}</Chip>
          <Chip on={tab === 'review'} onClick={() => setTab('review')}>In review {all.filter((r) => !r.reviewed).length}</Chip>
          <span style={{ flex: 1 }} />
          <button type="button" className="btn primary" onClick={() => nav('/library/new')}>New kata</button>
        </div>
        {mine.isLoading ? <div className="empty"><Dots /></div> : rows.length === 0 ? (
          <div className="empty">Nothing here yet. Publish from the app or start a kata on the web — drafts stay on your phone until published.</div>
        ) : (
          <div className="tbl">
            <div className="th">Kata</div><div className="th">Settings</div><div className="th hide-m">Sensor</div><div className="th hide-m">Version</div><div className="th">State</div><div className="th hide-m">Actions</div>
            {rows.map((r) => (
              <div key={r.id} style={{ display: 'contents' }}>
                <div className="td rowbtn" onClick={() => nav(`/library?r=${r.id}`)}>
                  {r.imageUrls[0] ? <img className="thumb" src={r.imageUrls[0]} alt="" /> : <span className="thumb" />}
                  <div style={{ minWidth: 0 }}><div className="name">{r.name}</div><div className="sub">edited {new Date(r.updatedAt).toLocaleDateString()}</div></div>
                </div>
                <div className="td hide-m"><span className="sub" style={{ fontFamily: 'var(--mono)', textTransform: 'uppercase' }}>{specSummary(r.ofr)}</span></div>
                <div className="td hide-m"><Swatch ofr={r.ofr} /></div>
                <div className="td hide-m" style={{ fontFamily: 'var(--mono)' }}>V{r.version}</div>
                <div className="td">{r.hidden ? <span className="pill red">Hidden</span> : r.reviewed ? <span className="pill solid">Verified</span> : <span className="pill">In review</span>}</div>
                <div className="td hide-m">
                  <button type="button" className="btn secondary" style={{ height: 28, fontSize: 11 }} onClick={() => nav(`/library/edit/${r.id}`)}>Edit</button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- editor (1e: rows + live code + compatibility + history)
const XT4_MISSING = new Set(['Nostalgic Negative', 'Reala Ace']);
const XT3_MISSING = new Set(['Nostalgic Negative', 'Reala Ace', 'Classic Negative', 'Eterna Bleach Bypass']);

export function Editor() {
  const { id } = useParams();
  const [params] = useSearchParams();
  const from = params.get('from') ?? undefined;
  const nav = useNavigate();
  const toast = useToast();
  const { client: api } = useAuth();
  const source = useRecipe(id ?? from);
  const publish = usePublish();
  const [o, setO] = useState<Ofr>({ film_simulation: 'Provia', dynamic_range: 'DR100', d_range_priority: 'Off', grain_roughness: 'Off', white_balance: 'Auto', white_balance_red: 0, white_balance_blue: 0, highlight: 0, shadow: 0, color: 0, sharpness: 0, high_iso_nr: 0, clarity: 0 });
  const [issues, setIssues] = useState<OfrIssue[]>([]);
  const [conflict, setConflict] = useState<string>();
  const [history, setHistory] = useState<{ current: number; items: { version: number; name: string; createdAt: string; ofr: Ofr }[] }>();
  useEffect(() => {
    if (!source.data) return;
    const base = { ...source.data.ofr };
    delete (base as Record<string, unknown>).hash;
    if (from) base.name = `${source.data.name} (copy)`;
    setO(base);
  }, [source.data, from]);
  const mono = MONO.has(o.film_simulation ?? '');
  const payload = useMemo(() => encodeKataCode(o), [o]);
  const set = (k: string, v: unknown) => setO((x) => ({ ...x, [k]: v === '' || v == null ? undefined : v }));
  const bump = (k: string, d: number, min: number, max: number) => setO((x) => {
    const cur = Number((x as Record<string, unknown>)[k] ?? 0);
    const next = Math.round((cur + d) * 2) / 2;
    return next < min || next > max ? x : { ...x, [k]: next };
  });
  const pasteCode = () => {
    const code = prompt('Paste a kata1: code or OFR JSON');
    if (!code) return;
    toast('Paste import lands with the importer — use the app for now', true);
  };
  const save = () => {
    const doc: Ofr = { ...o, v: 1 } as Ofr;
    delete (doc as Record<string, unknown>).hash;
    if (mono) { delete doc.color; delete doc.color_chrome_effect; delete doc.color_chrome_fx_blue; }
    else { delete doc.monochromatic_color_warm_cool; delete doc.monochromatic_color_magenta_green; }
    if (doc.white_balance !== 'Kelvin') delete doc.wb_kelvin;
    setIssues([]); setConflict(undefined);
    publish.mutate({ id, ofr: doc }, {
      onSuccess: (r) => { toast(id ? 'Saved — back in review' : 'Published'); nav(`/library?r=${r.id}`); },
      onError: (e) => {
        if (e instanceof PublishConflict) setConflict(e.existingId);
        else if (e instanceof PublishInvalid) setIssues(e.issues);
        else toast((e as Error).message, true);
      },
    });
  };
  const loadHistory = async () => {
    if (!id) return;
    try { setHistory(await api.get(`/recipes/${id}/versions`)); } catch { toast('No history yet', true); }
  };
  const compat = [
    { cls: 'ok', text: 'X-Trans V — all fields' },
    XT4_MISSING.has(o.film_simulation ?? '') ? { cls: 'warn', text: `X-Trans IV — ${o.film_simulation} unavailable` } : { cls: 'ok', text: `X-Trans IV — ${o.clarity ? 'Clarity write varies by body' : 'ok'}` },
    XT3_MISSING.has(o.film_simulation ?? '') ? { cls: 'warn', text: `X-Trans III — ${o.film_simulation} unavailable` } : { cls: 'ok', text: 'X-Trans III — read-only over USB' },
  ];
  const sel = (k: string, opts: string[], allowEmpty = false) => (
    <select value={(o as Record<string, unknown>)[k] as string ?? ''} onChange={(e) => set(k, e.target.value)}>
      {allowEmpty && <option value="">—</option>}
      {opts.map((x) => <option key={x}>{x}</option>)}
    </select>
  );
  const stepRow = (label: string, k: string, min: number, max: number, step = 1) => (
    <div className="frow"><span className="lbl">{label}</span><span className="val">
      <span className="step">
        <button type="button" onClick={() => bump(k, -step, min, max)} disabled={Number((o as Record<string, unknown>)[k] ?? 0) - step < min}>−</button>
        <span className="n">{fmt((o as Record<string, unknown>)[k] ?? 0)}</span>
        <button type="button" onClick={() => bump(k, step, min, max)} disabled={Number((o as Record<string, unknown>)[k] ?? 0) + step > max}>+</button>
      </span>
    </span></div>
  );
  return (
    <div className="ed">
      <div className="main">
        <div className="edhead">
          <h1>{id ? 'Edit kata' : 'New kata'}</h1>
          {id && source.data && <span className="pill">V{source.data.version}</span>}
          <span style={{ flex: 1 }} />
          {id && <button type="button" className="btn secondary" onClick={() => void loadHistory()}>History</button>}
          <button type="button" className="btn secondary" onClick={pasteCode}>Paste code</button>
          <button type="button" className="btn primary" disabled={publish.isPending || !o.name || !o.sensors?.length} onClick={save}>{publish.isPending ? <Dots /> : id ? 'Save changes' : 'Publish'}</button>
        </div>
        <div className="frow"><span className="lbl">Name</span><span className="val"><input type="text" value={o.name ?? ''} maxLength={60} onChange={(e) => set('name', e.target.value)} placeholder="e.g. Kodachrome 64" /></span></div>
        <div className="frow"><span className="lbl">Credit</span><span className="val"><input type="text" value={o.source_attribution ?? ''} maxLength={120} onChange={(e) => set('source_attribution', e.target.value)} /></span></div>
        <div className="frow"><span className="lbl">Source URL</span><span className="val"><input type="url" value={o.source_url ?? ''} onChange={(e) => set('source_url', e.target.value)} placeholder="https://" /></span></div>
        <div className="frow"><span className="lbl">Sensors</span><span className="val" style={{ justifyContent: 'flex-start', flexWrap: 'wrap' }}>
          {['X-Trans I', 'X-Trans II', 'X-Trans III', 'X-Trans IV', 'X-Trans V', 'GFX', 'Bayer'].map((s) => (
            <Chip key={s} on={o.sensors?.includes(s)} onClick={() => set('sensors', o.sensors?.includes(s) ? o.sensors.filter((x) => x !== s) : [...(o.sensors ?? []), s])}>{s}</Chip>
          ))}
        </span></div>
        <div className="frow"><span className="lbl">Film sim</span><span className="val">{sel('film_simulation', FILMS)}</span></div>
        <div className="frow"><span className="lbl">Dynamic range</span><span className="val">{sel('dynamic_range', ['DR100', 'DR200', 'DR400', 'DR-Auto'], true)}</span></div>
        <div className="frow"><span className="lbl">DR priority</span><span className="val">{sel('d_range_priority', ['Off', 'Auto', 'Weak', 'Strong'])}</span></div>
        <div className="frow"><span className="lbl">White balance</span><span className="val">
          {sel('white_balance', ['Auto', 'Auto (white priority)', 'Auto (ambience priority)', 'Daylight', 'Shade', 'Incandescent', 'Fluorescent 1', 'Fluorescent 2', 'Fluorescent 3', 'Kelvin', 'Underwater'])}
          {o.white_balance === 'Kelvin' && <input type="number" min={2500} max={10000} step={100} style={{ width: 90 }} value={o.wb_kelvin ?? 5500} onChange={(e) => set('wb_kelvin', Number(e.target.value))} />}
        </span></div>
        {stepRow('WB shift R', 'white_balance_red', -9, 9)}
        {stepRow('WB shift B', 'white_balance_blue', -9, 9)}
        {stepRow('Highlight', 'highlight', -2, 4, 0.5)}
        {stepRow('Shadow', 'shadow', -2, 4, 0.5)}
        {mono ? stepRow('Warm / cool', 'monochromatic_color_warm_cool', -9, 9) : stepRow('Color', 'color', -4, 4)}
        {mono && stepRow('Magenta / green', 'monochromatic_color_magenta_green', -9, 9)}
        {stepRow('Sharpness', 'sharpness', -4, 4)}
        {stepRow('High ISO NR', 'high_iso_nr', -4, 4)}
        {stepRow('Clarity', 'clarity', -5, 5)}
        <div className="frow"><span className="lbl">Grain</span><span className="val">{sel('grain_roughness', ['Off', 'Weak', 'Strong'])}{o.grain_roughness !== 'Off' && sel('grain_size', ['Small', 'Large'], true)}</span></div>
        {!mono && <div className="frow"><span className="lbl">Colour chrome</span><span className="val">{sel('color_chrome_effect', ['Off', 'Weak', 'Strong'], true)}{sel('color_chrome_fx_blue', ['Off', 'Weak', 'Strong'], true)}</span></div>}
        <div className="livecode">
          <div className="pay">{payload}</div>
          <div className="cap">KATA CODE · LIVE · {payload.length} BYTES · UPDATES AS YOU TYPE</div>
        </div>
        {issues.length > 0 && <div className="issue">{issues.map((i) => <div key={i.field + i.message}>{i.field}: {i.message}</div>)}</div>}
        {conflict && <div className="note">A kata with exactly these settings already exists (names don't count). <a href={`/library?r=${conflict}`}>Open it</a> or change a setting.</div>}
        {id && <div className="note">Edits go back into the review queue — the verified badge comes off until a curator re-checks.</div>}
      </div>
      <aside className="aside">
        <h3 style={{ margin: '0 0 10px', font: '500 9px/1 var(--mono)', letterSpacing: '.18em', color: 'var(--muted)', textTransform: 'uppercase' }}>Compatibility</h3>
        <div className="compat">{compat.map((c) => <div key={c.text} className={c.cls}>{c.text}</div>)}</div>
        {history && (
          <>
            <h3 style={{ margin: '18px 0 10px', font: '500 9px/1 var(--mono)', letterSpacing: '.18em', color: 'var(--muted)', textTransform: 'uppercase' }}>History · keeps the last 10</h3>
            <div className="hlist">
              {history.items.map((v) => (
                <div key={v.version} className="hrow">
                  <span className="v">V{v.version}</span>
                  <span style={{ flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis' }}>{v.name}</span>
                  {v.version !== history.current && (
                    <button type="button" className="btn secondary" style={{ height: 26, fontSize: 10.5 }} onClick={() => { setO(() => { const b = { ...v.ofr }; delete (b as Record<string, unknown>).hash; return b; }); toast(`Loaded V${v.version} — publish to make it current`); }}>Load</button>
                  )}
                </div>
              ))}
              {history.items.length === 0 && <div className="hrow">No snapshots yet — history starts with your first edit.</div>}
            </div>
          </>
        )}
      </aside>
    </div>
  );
}

// ---------------------------------------------------------------- settings (1j web: account · camera profiles · data)
export function Settings() {
  const { user, signOut, client: api } = useAuth();
  const toast = useToast();
  const [handle, setHandle] = useState(user?.handle ?? '');
  const [name, setName] = useState(user?.displayName ?? '');
  const [cams, setCams] = useState<{ model: string; firmware: string; slots: number; lastSeen: string }[]>();
  useEffect(() => { api.get<{ items: typeof cams }>('/me/cameras').then((d) => setCams(d.items ?? [])).catch(() => setCams([])); }, [api]);
  const saveProfile = async () => {
    try {
      await api.patch('/me', { handle: handle || undefined, displayName: name || undefined });
      toast('Profile saved');
    } catch (e) { toast((e as Error).message, true); }
  };
  return (
    <div className="set">
      <div className="setcard">
        <h3>Account</h3>
        <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginBottom: 12 }}>
          {user?.photoUrl ? <img className="avatar" src={user.photoUrl} alt="" style={{ width: 36, height: 36 }} referrerPolicy="no-referrer" /> : <span className="avatar" style={{ width: 36, height: 36 }}>{user?.displayName.slice(0, 2).toUpperCase()}</span>}
          <div><div style={{ fontWeight: 600 }}>{user?.displayName}</div><div style={{ fontSize: 11, color: 'var(--muted)' }}>{user?.email}</div></div>
        </div>
        <div className="frow"><span className="lbl">Display name</span><span className="val"><input type="text" value={name} onChange={(e) => setName(e.target.value)} maxLength={60} /></span></div>
        <div className="frow"><span className="lbl">@handle</span><span className="val"><input type="text" value={handle} onChange={(e) => setHandle(e.target.value.toLowerCase())} placeholder="yourname" maxLength={20} /></span></div>
        <p style={{ fontSize: 11, color: 'var(--muted)', margin: '10px 0' }}>Your handle is the credit line on cards and Kata Codes you publish. Lowercase letters, digits, dots, underscores — 3–20 characters.</p>
        <div style={{ display: 'flex', gap: 8 }}>
          <button type="button" className="btn primary" onClick={() => void saveProfile()}>Save</button>
          <button type="button" className="btn secondary" onClick={() => { if (confirm('Sign out?')) void signOut(); }}>Sign out</button>
        </div>
      </div>
      <div className="setcard">
        <h3>Camera profiles</h3>
        {!cams ? <Dots /> : cams.length === 0 ? <p style={{ margin: 0, color: 'var(--muted)', fontSize: 12 }}>No bodies yet — connect a camera in the Kata app and it shows up here.</p> : (
          <div className="kv">{cams.map((c) => <><div key={c.model + c.firmware}>{c.model}</div><div className="m">FW {c.firmware || '—'} · C1–C{c.slots} · {new Date(c.lastSeen).toLocaleDateString()}</div></>)}</div>
        )}
      </div>
      <div className="setcard">
        <h3>Write behaviour</h3>
        <p style={{ margin: 0, color: 'var(--muted)', fontSize: 12, lineHeight: 1.6 }}>Slot backups, batch writes and the field-level diff live in the desktop and Android apps — the web can't reach your camera. <a href="/kata.apk" style={{ color: 'var(--dim)', textDecoration: 'underline' }}>Get the app</a>.</p>
      </div>
    </div>
  );
}
