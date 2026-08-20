import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';

export const cx = (...a: (string | false | null | undefined)[]) => a.filter(Boolean).join(' ');
export function Dots() { return <span className="dots" aria-label="Loading"><i /><i /><i /></span>; }
export function Chip({ on, onClick, children }: { on?: boolean; onClick?: () => void; children: ReactNode }) {
  return <button type="button" className={cx('chip', on && 'on')} onClick={onClick} aria-pressed={on}>{children}</button>;
}
export function Swatch({ ofr, light }: { ofr: Record<string, unknown>; light?: boolean }) {
  const n = (v: unknown, min: number, max: number) => 0.25 + 0.75 * Math.min(1, Math.max(0, ((Number(v) || 0) - min) / (max - min)));
  const h = [n(ofr.highlight, -2, 4), n(ofr.shadow, -2, 4), n(ofr.color, -4, 4), n(ofr.sharpness, -4, 4), n(ofr.clarity, -5, 5)];
  const cols = light ? ['#000', '#2e2e2e', '#8a8a8a', '#d9d9d9'] : ['#fff', '#d9d9d9', '#8a8a8a', '#2e2e2e'];
  return (
    <span className="swatch" aria-hidden="true">
      {h.map((v, i) => <i key={i} style={{ height: `${v * 100}%`, background: cols[(Math.round(v * 7) + i) % 4] }} />)}
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
