import express from 'express';
import session from 'express-session';
import connectPgSimple from 'connect-pg-simple';
import helmet from 'helmet';
import { createAuthService, createGoogleProvider, AuthError } from './services/authService.js';
import { authRoutes } from './routes/authRoutes.js';
export function createApp({ config, pool, provider = createGoogleProvider(config), store }) {
  const app = express();
  app.disable('x-powered-by');
  if (config.trustProxy) app.set('trust proxy', 1);
  app.use(helmet());
  app.use('/api/auth', (req, res, next) => { res.set('Cache-Control', 'no-store'); res.set('Pragma', 'no-cache'); next(); });
  const PgStore = connectPgSimple(session);
  app.use(session({ name: config.cookieName, secret: config.secret,
    store: store || new PgStore({ pool, tableName: 'auth_sessions', createTableIfMissing: false }),
    resave: false, saveUninitialized: false, rolling: false,
    cookie: { httpOnly: true, secure: config.secure, sameSite: 'lax', maxAge: config.ttlMs, path: '/' } }));
  app.use('/api/auth', authRoutes(createAuthService({ config, pool, provider }), config));
  app.use((req, res) => res.status(404).json({ error: 'not_found' }));
  app.use((error, req, res, next) => {
    if (res.headersSent) return next(error);
    if (error instanceof AuthError) return res.status(error.status).json({ error: error.code });
    console.error('Authentication request failed', { type: error.constructor.name, code: error.code });
    res.status(500).json({ error: 'server_error', message: 'Authentication is temporarily unavailable. Please try again.' });
  });
  return app;
}
