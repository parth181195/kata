import { Navigate, Route, Routes } from 'react-router';
import { useAuth } from './auth/AuthProvider';
import { NotAdmin, SignIn } from './auth/SignIn';
import { Cameras } from './pages/Cameras';
import { Creators } from './pages/Creators';
import { Layout } from './pages/Layout';
import { Queue } from './pages/Queue';
import { Reports } from './pages/Reports';
import { Settings } from './pages/Settings';
import { Dots } from './ui';

export default function App() {
  const { status, user } = useAuth();
  if (status === 'booting') return <div className="auth"><Dots /></div>;
  if (status === 'signedOut') return <SignIn />;
  if (user?.role !== 'admin') return <NotAdmin />;
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Queue mode="queue" />} />
        <Route path="recipes" element={<Queue mode="recipes" />} />
        <Route path="creators" element={<Creators />} />
        <Route path="reports" element={<Reports />} />
        <Route path="cameras" element={<Cameras />} />
        <Route path="settings" element={<Settings />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}
