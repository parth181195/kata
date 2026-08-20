import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router';
import App from './App';
import { AuthProvider } from './AuthProvider';
import './app.css';
import { ToastHost } from './ui';

const qc = new QueryClient({ defaultOptions: { queries: { retry: 1, staleTime: 10_000, refetchOnWindowFocus: false } } });

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={qc}>
      <AuthProvider>
        <ToastHost>
          <BrowserRouter>
            <App />
          </BrowserRouter>
        </ToastHost>
      </AuthProvider>
    </QueryClientProvider>
  </StrictMode>,
);
