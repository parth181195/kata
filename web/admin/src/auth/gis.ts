/** Google Identity Services loader + ID-token button. */
declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize(cfg: { client_id: string; callback: (r: { credential: string }) => void; ux_mode?: string; auto_select?: boolean }): void;
          renderButton(el: HTMLElement, opts: Record<string, unknown>): void;
          prompt(): void;
          disableAutoSelect(): void;
        };
      };
    };
  }
}
export const GOOGLE_CLIENT_ID: string = (import.meta.env.VITE_GOOGLE_WEB_CLIENT_ID as string | undefined) ?? '';

let loading: Promise<void> | null = null;
export function loadGis(): Promise<void> {
  if (window.google?.accounts?.id) return Promise.resolve();
  if (loading) return loading;
  loading = new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = 'https://accounts.google.com/gsi/client';
    s.async = true;
    s.defer = true;
    s.onload = () => resolve();
    s.onerror = () => reject(new Error('Could not load Google Sign-In'));
    document.head.appendChild(s);
  });
  return loading;
}
