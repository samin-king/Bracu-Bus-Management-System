import React from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { useState } from 'react';
import AuthProvider from './components/AuthProvider.jsx';
import ProtectedRoute from './components/ProtectedRoute.jsx';
import Login from './pages/Login.jsx';
import { useAuth } from './hooks/useAuth.js';
function AuthenticatedIdentity() {
  const { user, logout } = useAuth();
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  async function signOut() {
    setBusy(true);
    try { await logout(); } catch { setError('Sign out failed. Please try again.'); }
    finally { setBusy(false); }
  }
  return <main className="max-w-lg mx-auto mt-16 bg-white rounded-xl p-8 shadow">
    <h1 className="text-2xl font-semibold text-blue-900">BRAC University</h1>
    <p className="mt-4">Signed in as {user.name}</p><p className="text-slate-600 break-all">{user.email}</p>
    {error && <p role="alert" className="text-red-800">{error}</p>}
    <button disabled={busy} onClick={signOut} className="mt-6 rounded bg-blue-900 text-white px-5 py-2">{busy ? 'Signing out...' : 'Sign out'}</button>
  </main>;
}
export default function App() {
  return <BrowserRouter><AuthProvider><Routes>
    <Route path="/login" element={<Login />} />
    <Route element={<ProtectedRoute />}><Route path="/" element={<AuthenticatedIdentity />} /></Route>
    <Route path="*" element={<Navigate to="/" replace />} />
  </Routes></AuthProvider></BrowserRouter>;
}
