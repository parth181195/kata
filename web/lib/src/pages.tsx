import QRCode from 'qrcode';
import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { specSummary, useDelete, useFavourites, useMine, usePublish, useRecipe, useRecipes, useReport, useToggleFavourite, PublishConflict, PublishInvalid, type Filter, type OfrIssue } from './api';
import { useAuth } from './AuthProvider';
import { encodeKataCode } from './kataCode';
import type { Ofr } from './types';
import { Chip, Dots, Swatch, useToast } from './ui';

const SENSORS = ['X-Trans V', 'X-Trans IV', 'X-Trans III', 'GFX', 'Bayer'];

// ---------------------------------------------------------------- library
export function Library() {
  const [q, setQ] = useState('');
  const [f, setF] = useState<Filter>({ sort: 'newest' });
  const [dq, setDq] = useState('');
  useEffect(() => { const t = setTimeout(() => setDq(q), 250); return () => clearTimeout(t); }, [q]);
  const filter = useMemo(() => ({ ...f, q: dq || undefined }), [f, dq]);
  const recipes = useRecipes(filter);
  const favs = useFavourites();
  const toggle = useToggleFavourite();
  const rows = recipes.data?.pages.flatMap((p) => p.items) ?? [];
  return (
    <main className="wrap">
      <div style={{ display: 'flex', gap: 10, alignItems: 'center', paddingTop: 16, flexWrap: 'wrap' }}>
        <label className="search"><input placeholder="Search recipes, film sims, authors" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search" /></label>
        <button type="button" className="chip" onClick={() => setF((x) => ({ ...x, sort: x.sort === 'newest' ? 'popular' : 'newest' }))}>{f.sort === 'newest' ? 'NEWEST' : 'MOST SAVED'} ▾</button>
      </div>
      <div className="chips">
        <Chip on={!!f.verified} onClick={() => setF((x) => ({ ...x, verified: x.verified ? undefined : true }))}>Verified</Chip>
        {SENSORS.map((s) => <Chip key={s} on={f.sensor === s} onClick={() => setF((x) => ({ ...x, sensor: x.sensor === s ? undefined : s }))}>{s}</Chip>)}
        <Chip on={f.mono === true} onClick={() => setF((x) => ({ ...x, mono: x.mono ? undefined : true }))}>B&amp;W</Chip>
      </div>
      {recipes.isLoading ? <div className="empty"><Dots /></div> : rows.length === 0 ? <div className="empty">No katas match.</div> : (
        <div className="grid">
          {rows.map((r) => (
            <Link key={r.id} className="tile" to={`/r/${r.id}`}>
              {r.imageUrls[0] && <img src={r.imageUrls[0]} alt="" loading="lazy" />}
              <span className="shade" />
              {r.reviewed && <span className="ver"><i />VERIFIED</span>}
              <button
                type="button"
                className={favs.data?.has(r.id) ? 'fav on' : 'fav'}
                aria-label="Save"
                onClick={(e) => { e.preventDefault(); toggle.mutate({ id: r.id, on: !favs.data?.has(r.id) }); }}
              >{favs.data?.has(r.id) ? '♥' : '♡'}</button>
              <span className="meta">
                <span className="name">{r.name}</span>
                <span className="spec"><span>{r.filmSim}<br />{(r.ofr.dynamic_range as string) ?? ''} · {r.ofr.white_balance === 'Kelvin' ? `${r.ofr.wb_kelvin}K` : (r.ofr.white_balance as string) ?? ''}</span><Swatch ofr={r.ofr} /></span>
              </span>
            </Link>
          ))}
        </div>
      )}
      {recipes.hasNextPage && <div style={{ paddingBottom: 40 }}><button type="button" className="btn secondary sm" onClick={() => void recipes.fetchNextPage()}>{recipes.isFetchingNextPage ? <Dots /> : 'Load more'}</button></div>}
    </main>
  );
}

// ---------------------------------------------------------------- recipe page
const SPEC: [keyof Ofr & string, string][] = [
  ['film_simulation', 'Film sim'], ['dynamic_range', 'Dynamic range'], ['d_range_priority', 'DR priority'],
  ['white_balance', 'White balance'], ['wb_kelvin', 'Kelvin'], ['white_balance_red', 'WB shift R'], ['white_balance_blue', 'WB shift B'],
  ['highlight', 'Highlight'], ['shadow', 'Shadow'], ['color', 'Color'], ['sharpness', 'Sharpness'], ['high_iso_nr', 'High ISO NR'],
  ['clarity', 'Clarity'], ['grain_roughness', 'Grain'], ['grain_size', 'Grain size'], ['color_chrome_effect', 'CC effect'],
  ['color_chrome_fx_blue', 'CC blue'], ['monochromatic_color_warm_cool', 'Warm/cool'], ['monochromatic_color_magenta_green', 'Magenta/green'],
];
const fmt = (v: unknown) => v == null ? '—' : typeof v === 'number' && v > 0 ? `+${v}` : String(v);

export function RecipePage() {
  const { id } = useParams();
  const nav = useNavigate();
  const { user } = useAuth();
  const q = useRecipe(id);
  const favs = useFavourites();
  const toggle = useToggleFavourite();
  const report = useReport();
  const del = useDelete();
  const toast = useToast();
  const [qr, setQr] = useState<string>();
  const r = q.data;
  const payload = useMemo(() => (r ? encodeKataCode(r.ofr) : ''), [r]);
  useEffect(() => {
    if (!payload) return;
    QRCode.toDataURL(payload, { errorCorrectionLevel: 'M', margin: 4, width: 224, color: { dark: '#000000', light: '#ffffff' } }).then(setQr).catch(() => setQr(undefined));
  }, [payload]);
  if (q.isLoading) return <main className="wrap"><div className="empty"><Dots /></div></main>;
  if (!r) return <main className="wrap"><div className="empty">This kata doesn't exist (or was unpublished).<br /><Link to="/library" style={{ textDecoration: 'underline' }}>Back to the library</Link></div></main>;
  const fav = favs.data?.has(r.id) ?? false;
  const own = user && r.authorId === user.id;
  return (
    <main className="wrap rp">
      <div className="photos">
        <div className="main">{r.imageUrls[0] ? <img src={r.imageUrls[0]} alt={r.name} /> : null}</div>
        {r.imageUrls.length > 1 && <div className="row">{r.imageUrls.slice(1, 3).map((u) => <img key={u} src={u} alt="" loading="lazy" />)}</div>}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div>
          <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap', marginBottom: 8 }}>
            {r.reviewed && <span className="pill solid">Verified</span>}
            {r.sensors.map((s) => <span key={s} className="pill">{s}</span>)}
            {own && <span className="pill">{r.reviewed ? 'Yours' : 'Yours · in review'}</span>}
          </div>
          <h1>{r.name}</h1>
          <p className="sub" style={{ marginTop: 8 }}>{specSummary(r.ofr)}</p>
          <p className="credit" style={{ marginTop: 6, fontSize: 12, color: 'var(--muted)' }}>
            {r.sourceAttribution ?? 'Community'}{r.sourceUrl && <> · <a href={r.sourceUrl} target="_blank" rel="noreferrer">source post ↗</a></>}
          </p>
        </div>
        <div className="actions">
          <button type="button" className="btn secondary sm" onClick={() => toggle.mutate({ id: r.id, on: !fav })}>{fav ? '♥ Saved' : '♡ Save'}</button>
          <button type="button" className="btn secondary sm" onClick={() => { void navigator.clipboard.writeText(payload); toast('Kata Code copied'); }}>Copy Kata Code</button>
          <button type="button" className="btn secondary sm" onClick={() => { void navigator.clipboard.writeText(location.href); toast('Link copied'); }}>Copy link</button>
          {own && <button type="button" className="btn secondary sm" onClick={() => nav(`/library/edit/${r.id}`)}>Edit</button>}
          {own && <button type="button" className="btn danger sm" onClick={() => { if (confirm(`Unpublish “${r.name}”?`)) del.mutate(r.id, { onSuccess: () => nav('/library') }); }}>Unpublish</button>}
          {!own && <button type="button" className="btn secondary sm" onClick={() => { const reason = prompt('What’s wrong with this kata?'); if (reason) report.mutate({ id: r.id, reason }, { onSuccess: () => toast('Thanks — sent to the curators') }); }}>Report</button>}
        </div>
        <div className="specgrid">
          {SPEC.filter(([k]) => r.ofr[k] != null).map(([k, label]) => <div key={k}><div className="k">{label}</div><div className="v">{fmt(r.ofr[k])}</div></div>)}
        </div>
        <div className="codecard">
          {qr && <img src={qr} alt="Kata Code — scan in the Kata app to import this recipe" />}
          <div style={{ minWidth: 0 }}>
            <div style={{ font: '800 13px/1.2 var(--display)', textTransform: 'uppercase', marginBottom: 6 }}>Kata Code</div>
            <div className="pay">{payload}</div>
          </div>
        </div>
        <div className="appcard">
          <b>Write it to your camera</b>
          <p>Writing into C1–C7 happens over USB-C in the Kata Android app — scan the code above with the app, or find this kata in its library. <a href="/kata.apk" style={{ color: 'var(--dim)', textDecoration: 'underline' }}>Get the app</a>.</p>
        </div>
      </div>
    </main>
  );
}

// ---------------------------------------------------------------- mine + editor
export function Mine() {
  const mine = useMine();
  const rows = mine.data?.items ?? [];
  return (
    <main className="wrap">
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '18px 0 4px' }}>
        <h1 style={{ margin: 0, font: '800 22px/1 var(--display)', textTransform: 'uppercase', flex: 1 }}>Mine</h1>
        <Link className="btn primary sm" to="/library/new">New kata</Link>
      </div>
      {mine.isLoading ? <div className="empty"><Dots /></div> : rows.length === 0 ? <div className="empty">Nothing published yet — publish from the app, or start one here.</div> : (
        <div className="grid">
          {rows.map((r) => (
            <Link key={r.id} className="tile" to={`/r/${r.id}`}>
              {r.imageUrls[0] && <img src={r.imageUrls[0]} alt="" loading="lazy" />}
              <span className="shade" />
              <span className="ver"><i />{r.hidden ? 'HIDDEN' : r.reviewed ? 'VERIFIED' : 'IN REVIEW'}</span>
              <span className="meta"><span className="name">{r.name}</span><span className="spec"><span>{r.filmSim}</span><Swatch ofr={r.ofr} /></span></span>
            </Link>
          ))}
        </div>
      )}
    </main>
  );
}

const FILMS = ['Provia', 'Velvia', 'Astia', 'Classic Chrome', 'Pro Neg. Hi', 'Pro Neg. Std', 'Classic Negative', 'Eterna', 'Eterna Bleach Bypass', 'Nostalgic Negative', 'Reala Ace', 'Acros STD', 'Acros Yellow', 'Acros Red', 'Acros Green', 'Monochrome STD', 'Monochrome Yellow', 'Monochrome Red', 'Monochrome Green', 'Sepia'];
const MONO = new Set(FILMS.slice(11));
const WBS = ['Auto', 'Auto (white priority)', 'Auto (ambience priority)', 'Daylight', 'Shade', 'Incandescent', 'Fluorescent 1', 'Fluorescent 2', 'Fluorescent 3', 'Kelvin', 'Underwater'];

export function Editor() {
  const { id } = useParams();
  const nav = useNavigate();
  const toast = useToast();
  const existing = useRecipe(id);
  const publish = usePublish();
  const [o, setO] = useState<Ofr>({ film_simulation: 'Provia', dynamic_range: 'DR100', d_range_priority: 'Off', grain_roughness: 'Off', white_balance: 'Auto', white_balance_red: 0, white_balance_blue: 0, highlight: 0, shadow: 0, color: 0, sharpness: 0, high_iso_nr: 0, clarity: 0 });
  const [issues, setIssues] = useState<OfrIssue[]>([]);
  const [conflict, setConflict] = useState<string>();
  useEffect(() => { if (existing.data) setO(existing.data.ofr); }, [existing.data]);
  const mono = MONO.has(o.film_simulation ?? '');
  const set = (k: string, v: unknown) => setO((x) => ({ ...x, [k]: v === '' || v == null ? undefined : v }));
  const num = (k: string, v: string) => set(k, v === '' ? undefined : Number(v));
  const save = () => {
    const doc: Ofr = { ...o, v: 1 } as Ofr;
    delete (doc as Record<string, unknown>).hash;
    if (mono) { delete doc.color; delete doc.color_chrome_effect; delete doc.color_chrome_fx_blue; }
    else { delete doc.monochromatic_color_warm_cool; delete doc.monochromatic_color_magenta_green; }
    if (doc.white_balance !== 'Kelvin') delete doc.wb_kelvin;
    setIssues([]); setConflict(undefined);
    publish.mutate({ id, ofr: doc }, {
      onSuccess: (r) => { toast(id ? 'Saved — back in review' : 'Published'); nav(`/r/${r.id}`); },
      onError: (e) => {
        if (e instanceof PublishConflict) setConflict(e.existingId);
        else if (e instanceof PublishInvalid) setIssues(e.issues);
        else toast((e as Error).message, true);
      },
    });
  };
  return (
    <main className="wrap form">
      <h1 style={{ margin: 0, font: '800 22px/1 var(--display)', textTransform: 'uppercase' }}>{id ? 'Edit kata' : 'New kata'}</h1>
      <div className="field"><label>Name</label><input value={o.name ?? ''} maxLength={60} onChange={(e) => set('name', e.target.value)} placeholder="e.g. Kodachrome 64" /></div>
      <p style={{ margin: '-6px 0 0', fontSize: 11, color: 'var(--muted)' }}>The name lives in Kata and on cards. Cameras keep at most 25 characters; some store none.</p>
      <div className="two">
        <div className="field"><label>Credit</label><input value={o.source_attribution ?? ''} maxLength={120} onChange={(e) => set('source_attribution', e.target.value)} /></div>
        <div className="field"><label>Source URL</label><input value={o.source_url ?? ''} onChange={(e) => set('source_url', e.target.value)} placeholder="https://" /></div>
      </div>
      <div className="field"><label>Sensors</label>
        <div className="chips" style={{ padding: 0 }}>
          {['X-Trans I', 'X-Trans II', 'X-Trans III', 'X-Trans IV', 'X-Trans V', 'GFX', 'Bayer'].map((s) => (
            <Chip key={s} on={o.sensors?.includes(s)} onClick={() => set('sensors', o.sensors?.includes(s) ? o.sensors.filter((x) => x !== s) : [...(o.sensors ?? []), s])}>{s}</Chip>
          ))}
        </div>
      </div>
      <div className="two">
        <div className="field"><label>Film simulation</label>
          <select value={o.film_simulation} onChange={(e) => set('film_simulation', e.target.value)}>{FILMS.map((f) => <option key={f}>{f}</option>)}</select>
        </div>
        <div className="field"><label>Dynamic range</label>
          <select value={o.dynamic_range ?? ''} onChange={(e) => set('dynamic_range', e.target.value)}><option value="">—</option>{['DR100', 'DR200', 'DR400', 'DR-Auto'].map((d) => <option key={d}>{d}</option>)}</select>
        </div>
      </div>
      <div className="two">
        <div className="field"><label>Grain</label>
          <select value={o.grain_roughness ?? 'Off'} onChange={(e) => set('grain_roughness', e.target.value)}>{['Off', 'Weak', 'Strong'].map((d) => <option key={d}>{d}</option>)}</select>
        </div>
        <div className="field"><label>Grain size</label>
          <select value={o.grain_size ?? ''} disabled={o.grain_roughness === 'Off'} onChange={(e) => set('grain_size', e.target.value)}><option value="">—</option><option>Small</option><option>Large</option></select>
        </div>
      </div>
      <div className="two">
        <div className="field"><label>White balance</label>
          <select value={o.white_balance} onChange={(e) => set('white_balance', e.target.value)}>{WBS.map((w) => <option key={w}>{w}</option>)}</select>
        </div>
        {o.white_balance === 'Kelvin' ? <div className="field"><label>Kelvin</label><input type="number" min={2500} max={10000} step={100} value={o.wb_kelvin ?? 5500} onChange={(e) => num('wb_kelvin', e.target.value)} /></div> : <div />}
      </div>
      <div className="two">
        <div className="field"><label>WB shift R (−9…9)</label><input type="number" min={-9} max={9} value={o.white_balance_red ?? 0} onChange={(e) => num('white_balance_red', e.target.value)} /></div>
        <div className="field"><label>WB shift B (−9…9)</label><input type="number" min={-9} max={9} value={o.white_balance_blue ?? 0} onChange={(e) => num('white_balance_blue', e.target.value)} /></div>
      </div>
      <div className="two">
        <div className="field"><label>Highlight (−2…4)</label><input type="number" min={-2} max={4} step={0.5} value={o.highlight ?? 0} onChange={(e) => num('highlight', e.target.value)} /></div>
        <div className="field"><label>Shadow (−2…4)</label><input type="number" min={-2} max={4} step={0.5} value={o.shadow ?? 0} onChange={(e) => num('shadow', e.target.value)} /></div>
      </div>
      <div className="two">
        {mono
          ? <div className="field"><label>Warm / cool (−9…9)</label><input type="number" min={-9} max={9} value={o.monochromatic_color_warm_cool ?? 0} onChange={(e) => num('monochromatic_color_warm_cool', e.target.value)} /></div>
          : <div className="field"><label>Color (−4…4)</label><input type="number" min={-4} max={4} value={o.color ?? 0} onChange={(e) => num('color', e.target.value)} /></div>}
        <div className="field"><label>Sharpness (−4…4)</label><input type="number" min={-4} max={4} value={o.sharpness ?? 0} onChange={(e) => num('sharpness', e.target.value)} /></div>
      </div>
      <div className="two">
        <div className="field"><label>High ISO NR (−4…4)</label><input type="number" min={-4} max={4} value={o.high_iso_nr ?? 0} onChange={(e) => num('high_iso_nr', e.target.value)} /></div>
        <div className="field"><label>Clarity (−5…5)</label><input type="number" min={-5} max={5} value={o.clarity ?? 0} onChange={(e) => num('clarity', e.target.value)} /></div>
      </div>
      {issues.length > 0 && <div className="issue">{issues.map((i) => <div key={i.field}>{i.field}: {i.message}</div>)}</div>}
      {conflict && <div className="issue" style={{ borderColor: 'var(--hair2)', color: 'var(--dim)' }}>A kata with exactly these settings already exists (names don't count). <Link to={`/r/${conflict}`} style={{ textDecoration: 'underline' }}>Open it</Link> or change a setting.</div>}
      <div className="actions">
        <button type="button" className="btn primary" disabled={publish.isPending || !o.name || !o.sensors?.length} onClick={save}>{publish.isPending ? <Dots /> : id ? 'Save changes' : 'Publish'}</button>
        {id && <span style={{ alignSelf: 'center', fontSize: 11, color: 'var(--muted)' }}>Edits go back into the review queue.</span>}
      </div>
    </main>
  );
}
