import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { AuthContext } from '../hooks/useAuth.js';
import ProtectedRoute from '../components/ProtectedRoute.jsx';
import Login from '../pages/Login.jsx';
import AuthProvider from '../components/AuthProvider.jsx';
import { authApi } from '../services/authApi.js';
vi.mock('../services/authApi.js', () => ({ authApi: { login: vi.fn(), me: vi.fn(), logout: vi.fn() } }));
const auth = { authenticated: false, loading: false, refresh: vi.fn() };
function view(element, value = auth, path = '/') {
  return render(<AuthContext.Provider value={value}><MemoryRouter initialEntries={[path]}><Routes>
    <Route path="/" element={element} /><Route path="/login" element={<Login />} />
  </Routes></MemoryRouter></AuthContext.Provider>);
}
describe('authentication UI', () => {
  it('renders login branding and initiates Google authorization', () => {
    view(<Login />);
    expect(screen.getByText('BRAC University')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'BRACU SMART TRANSPORT' })).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Continue with BRACU Google' }));
    expect(authApi.login).toHaveBeenCalledOnce();
    expect(screen.getByRole('button', { name: 'Signing in...' })).toBeDisabled();
    fireEvent.click(screen.getByRole('button', { name: 'Signing in...' }));
    expect(authApi.login).toHaveBeenCalledOnce();
  });
  it('redirects unauthenticated protected routes to login', () => {
    view(<ProtectedRoute><p>Private</p></ProtectedRoute>);
    expect(screen.getByRole('button', { name: 'Continue with BRACU Google' })).toBeInTheDocument();
    expect(screen.queryByText('Private')).not.toBeInTheDocument();
  });
  it('allows authenticated users', () => {
    view(<ProtectedRoute><p>Private</p></ProtectedRoute>, { ...auth, authenticated: true });
    expect(screen.getByText('Private')).toBeInTheDocument();
  });
  it('waits for authentication', () => {
    view(<ProtectedRoute />, { ...auth, loading: true });
    expect(screen.getByRole('status')).toHaveTextContent('Checking authentication');
  });
  it('shows institutional failure clearly', () => {
    view(<Login />, auth, '/login?error=invalid_institution');
    expect(screen.getByRole('alert')).toHaveTextContent('BRACU student Google Workspace');
  });
  it('surfaces service failures with retry', () => {
    view(<ProtectedRoute />, { ...auth, error: 'Unavailable' });
    fireEvent.click(screen.getByRole('button', { name: 'Retry' }));
    expect(auth.refresh).toHaveBeenCalled();
  });
  it('provider shares current-user request', async () => {
    authApi.me.mockResolvedValue(null);
    render(<AuthProvider><p>Consumers</p></AuthProvider>);
    await waitFor(() => expect(authApi.me).toHaveBeenCalledOnce());
  });
});

