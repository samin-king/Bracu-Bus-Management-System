import React, { useState } from 'react';
import { Navigate, useSearchParams } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth.js';
import { authApi } from '../services/authApi.js';

const messages = {
  invalid_institution: 'Use your BRACU student Google Workspace account to sign in.',
  invalid_callback: 'Your sign-in request expired or was invalid. Please start again.',
  google_denied: 'Google sign-in was cancelled. You can try again.',
  google_failed: 'Google could not verify your identity. Please try again.',
  account_conflict: 'This email is already linked to another identity. Contact support.'
};

export default function Login() {
  const { authenticated, loading, error, refresh } = useAuth();
  const [params] = useSearchParams();
  const [starting, setStarting] = useState(false);
  const [logoMissing, setLogoMissing] = useState(false);
  if (authenticated && !loading) return <Navigate to="/" replace />;
  const message = error || (params.has('error') ? messages[params.get('error')] || 'Sign-in failed. Please try again.' : '');

  return (
    <main className="auth-page">
      <div className="auth-layout">
        <header className="auth-brand">
          {!logoMissing && (
            <img
              className="auth-logo"
              src="/bracu-logo.png"
              alt="BRAC University logo"
              onError={() => setLogoMissing(true)}
            />
          )}
          {logoMissing && <p className="auth-university">BRAC University</p>}
          <h1>BRACU SMART TRANSPORT</h1>
          <p className="auth-subtitle">Bus Booking &amp; Tracking System</p>
        </header>

        <section className="auth-card" aria-labelledby="auth-welcome" aria-busy={loading || starting}>
          <h2 id="auth-welcome">Welcome to BRACU<br />Smart Transport</h2>
          <p className="auth-description">Login with your BRACU<br />Google Workspace account.</p>
          {loading ? (
            <p className="auth-status" role="status">Checking authentication...</p>
          ) : (
            <>
              {message && <p role="alert" className="auth-error">{message}</p>}
              <button
                type="button"
                disabled={starting}
                onClick={() => { setStarting(true); authApi.login(); }}
                className="auth-google-button"
              >
                <svg width="20" height="20" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
                  <path fill="#4285F4" d="M21.6 12.23c0-.71-.06-1.39-.18-2.05H12v3.88h5.38a4.6 4.6 0 0 1-2 3.02v2.51h3.24c1.89-1.74 2.98-4.31 2.98-7.36Z" />
                  <path fill="#34A853" d="M12 22c2.7 0 4.96-.9 6.62-2.41l-3.24-2.51c-.9.6-2.05.96-3.38.96-2.6 0-4.81-1.76-5.6-4.12H3.05v2.59A10 10 0 0 0 12 22Z" />
                  <path fill="#FBBC05" d="M6.4 13.92a6 6 0 0 1 0-3.84V7.49H3.05a10 10 0 0 0 0 9.02l3.35-2.59Z" />
                  <path fill="#EA4335" d="M12 5.96c1.47 0 2.79.51 3.83 1.51l2.87-2.87A9.6 9.6 0 0 0 12 2a10 10 0 0 0-8.95 5.49l3.35 2.59C7.19 7.72 9.4 5.96 12 5.96Z" />
                </svg>
                <span>{starting ? 'Signing in...' : 'Continue with BRACU Google'}</span>
              </button>
              {starting && <p className="auth-status" role="status">Connecting to Google...</p>}
              {error && <button type="button" onClick={refresh} className="auth-retry">Retry authentication check</button>}
              <p className="auth-note">For BRACU student accounts<br /><span>@g.bracu.ac.bd</span></p>
            </>
          )}
        </section>

        <footer className="auth-footer">
          <p>BRAC University</p>
          <p>Smart Transport System</p>
        </footer>
      </div>
    </main>
  );
}
