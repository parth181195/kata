import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';

export const cx = (...a: (string | false | null | undefined)[]) => a.filter(Boolean).join(' ');

export function Dots() { return <span className="dots" aria-label="Loading"><i /><i /><i /></span>; }

export function Pill({ kind = 'line', hollow, children }: { kind?: 'solid' | 'line' | 'dimmed' | 'red' | 'redsolid'; hollow?: boolean; children: ReactNode }) {
  return <span className={cx('pill', kind, hollow && 'hollow')}><i />{children}</span>;
}

export function Chip({ on, onClick, children }: { on?: boolean; onClick?: () => void; children: ReactNode }) {
  return <button type="button" className={cx('chip', on && 'on')} onClick={onClick} aria-pressed={on}>{children}</button>;
}

export function Checkbox({ on, onChange, label }: { on: boolean; onChange: (v: boolean) => void; label?: string }) {
  return <button type="button" role="checkbox" aria-checked={on} aria-label={label ?? 'select'} className={cx('cb', on && 'on')} onClick={(e) => { e.stopPropagation(); onChange(!on); }} />;
}

export function Avatar({ url, name, size = 28 }: { url: string | null | undefined; name: string; size?: number }) {
  const initials = name.split(/\s+/).map((s) => s[0]).join('').slice(0, 2).toUpperCase();
  return url ? <img className="avatar" src={url} alt="" width={size} height={size} style={{ width: size, height: size }} referrerPolicy="no-referrer" /> : <span className="avatar" style={{ width: size, height: size }}>{initials}</span>;
}

export function Empty({ glyph = '0', title, body, action }: { glyph?: string; title: string; body?: string; action?: ReactNode }) {
  return <div className="empty"><span className="glyph">{glyph}</span><h3>{title}</h3>{body && <p>{body}</p>}{action}</div>;
}

export function Thumb({ url, alt = '' }: { url?: string; alt?: string }) {
  return url ? <img className="thumb" src={url} alt={alt} loading="lazy" /> : <span className="thumb" aria-hidden="true" />;
}

// ---------------------------------------------------------------- toast
type Toast = { id: number; text: string; err?: boolean };
const ToastCtx = createContext<(text: string, err?: boolean) => void>(() => {});
export function ToastHost({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const push = useCallback((text: string, err = false) => {
    const id = Date.now() + Math.random();
    setToasts((t) => [...t, { id, text, err }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), err ? 5000 : 2600);
  }, []);
  const value = useMemo(() => push, [push]);
  return (
    <ToastCtx.Provider value={value}>
      {children}
      {toasts.map((t) => <div key={t.id} className={cx('toast', t.err && 'err')} role="status">{t.text}</div>)}
    </ToastCtx.Provider>
  );
}
export const useToast = () => useContext(ToastCtx);

// ---------------------------------------------------------------- confirm
export function useConfirm() {
  return useCallback((msg: string) => Promise.resolve(window.confirm(msg)), []);
}

// ---------------------------------------------------------------- misc
export function useDebounced<T>(v: T, ms = 250): T {
  const [d, setD] = useState(v);
  useEffect(() => { const t = setTimeout(() => setD(v), ms); return () => clearTimeout(t); }, [v, ms]);
  return d;
}
export function ago(iso: string | null | undefined): string {
  if (!iso) return '—';
  const s = (Date.now() - new Date(iso).getTime()) / 1000;
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)}m`;
  if (s < 86400) return `${Math.floor(s / 3600)}h`;
  const d = Math.floor(s / 86400);
  if (d < 30) return `${d}d ${Math.floor((s % 86400) / 3600)}h`;
  return new Date(iso).toISOString().slice(0, 10);
}
export const sensorShort = (s: string) => s.replace('X-Trans ', 'X-T ');
