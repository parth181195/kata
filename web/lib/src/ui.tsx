import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';

export const cx = (...a: (string | false | null | undefined)[]) => a.filter(Boolean).join(' ');
export function Dots() { return <span className="dots" aria-label="Loading"><i /><i /><i /></span>; }
export function Chip({ on, onClick, children }: { on?: boolean; onClick?: () => void; children: ReactNode }) {
  return <button type="button" className={cx('chip', on && 'on')} onClick={onClick} aria-pressed={on}>{children}</button>;
}
export function Swatch({ ofr, light }: { ofr: Record<string, unknown>; light?: boolean }) {
  // 0 is the camera's neutral for every one of these, so it sits on the axis and each side is
  // scaled by its own reach — a flat row is a neutral kata. Same mark as the apps draw.
  const n = (v: unknown, min: number, max: number) => {
    const x = Number(v) || 0;
    return x === 0 ? 0 : x > 0 ? Math.min(1, x / max) : -Math.min(1, x / min);
  };
  const vals = [n(ofr.highlight, -2, 4), n(ofr.shadow, -2, 4), n(ofr.color, -4, 4), n(ofr.sharpness, -4, 4), n(ofr.clarity, -5, 5)];
  const names = ['Highlight', 'Shadow', 'Colour', 'Sharpness', 'Clarity'];
  const title = vals.map((v, i) => `${names[i]} ${v === 0 ? 'neutral' : v > 0 ? 'up' : 'down'}`).join(' · ');
  return (
    <span className={cx('swatch', light && 'light')} title={title} aria-label={title}>
      {vals.map((v, i) => (
        <i key={i}>
          <b style={{ height: `${Math.max(v, 0) * 50}%` }} />
          <u style={{ height: `${Math.max(-v, 0) * 50}%` }} />
        </i>
      ))}
    </span>
  );
}
const ToastCtx = createContext<(text: string, err?: boolean) => void>(() => {});
export function ToastHost({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<{ id: number; text: string; err?: boolean }[]>([]);
  const push = useCallback((text: string, err = false) => {
    const id = Date.now() + Math.random();
    setToasts((t) => [...t, { id, text, err }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), err ? 5000 : 2600);
  }, []);
  const value = useMemo(() => push, [push]);
  return <ToastCtx.Provider value={value}>{children}{toasts.map((t) => <div key={t.id} className={cx('toast', t.err && 'err')} role="status">{t.text}</div>)}</ToastCtx.Provider>;
}
export const useToast = () => useContext(ToastCtx);

// ---------------------------------------------------------------- dialogs

type AskOpts = { title: string; body?: string; confirmLabel?: string; cancelLabel?: string; danger?: boolean };
type PromptOpts = AskOpts & { placeholder?: string; multiline?: boolean; initial?: string };
type Req =
  | ({ kind: 'confirm'; resolve: (v: boolean) => void } & AskOpts)
  | ({ kind: 'prompt'; resolve: (v: string | null) => void } & PromptOpts);

const DialogCtx = createContext<{ ask: (o: AskOpts) => Promise<boolean>; askText: (o: PromptOpts) => Promise<string | null> }>({
  ask: async () => false,
  askText: async () => null,
});

export function DialogHost({ children }: { children: ReactNode }) {
  const [req, setReq] = useState<Req | null>(null);
  const api = useMemo(() => ({
    ask: (o: AskOpts) => new Promise<boolean>((resolve) => setReq({ kind: 'confirm', ...o, resolve })),
    askText: (o: PromptOpts) => new Promise<string | null>((resolve) => setReq({ kind: 'prompt', ...o, resolve })),
  }), []);
  const close = useCallback((value: boolean | string | null) => {
    setReq((r) => {
      if (r) (r.resolve as (v: never) => void)(value as never);
      return null;
    });
  }, []);
  return <DialogCtx.Provider value={api}>{children}{req && <Dialog req={req} close={close} />}</DialogCtx.Provider>;
}

function Dialog({ req, close }: { req: Req; close: (v: boolean | string | null) => void }) {
  const [text, setText] = useState(req.kind === 'prompt' ? req.initial ?? '' : '');
  const first = useRef<HTMLInputElement & HTMLTextAreaElement>(null);
  const cancel = req.kind === 'prompt' ? null : false;
  useEffect(() => { first.current?.focus(); }, []);
  useEffect(() => {
    const esc = (e: KeyboardEvent) => { if (e.key === 'Escape') close(cancel); };
    window.addEventListener('keydown', esc);
    return () => window.removeEventListener('keydown', esc);
  }, [close, cancel]);
  const ok = () => close(req.kind === 'prompt' ? (text.trim() ? text.trim() : null) : true);
  return (
    <div className="backdrop" onMouseDown={(e) => { if (e.target === e.currentTarget) close(cancel); }}>
      <div className="dialog" role="dialog" aria-modal="true" aria-label={req.title}>
        <h3>{req.title}</h3>
        {req.body && <p>{req.body}</p>}
        {req.kind === 'prompt' && (req.multiline
          ? <textarea ref={first} value={text} placeholder={req.placeholder} rows={4} onChange={(e) => setText(e.target.value)} />
          : <input ref={first} type="text" value={text} placeholder={req.placeholder} onChange={(e) => setText(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') ok(); }} />)}
        <div className="drow">
          <button type="button" className="btn secondary" onClick={() => close(cancel)}>{req.cancelLabel ?? 'Cancel'}</button>
          <button type="button" className={cx('btn', req.danger ? 'danger' : 'primary')} onClick={ok}
            disabled={req.kind === 'prompt' && !text.trim()}>{req.confirmLabel ?? 'OK'}</button>
        </div>
      </div>
    </div>
  );
}

export const useDialog = () => useContext(DialogCtx);
