import express from 'express';
import session from 'express-session';
import connectPgSimple from 'connect-pg-simple';
import helmet from 'helmet';
import { createAuthService, createGoogleProvider, AuthError } from '../../Bracu-Bus-Management-System/services/src/services/authService.js';
import { authRoutes } from '../../Bracu-Bus-Management-System/services/src/routes/authRoutes.js';
import { requireAuth, requireSameOrigin } from '../../Bracu-Bus-Management-System/services/src/middleware/authMiddleware.js';
import { createApp as createTransportApp } from './app.js';
import {authorizedAccounts} from './authorizedAccounts.js';

// Reuse Member 1 OAuth/session contracts without editing that member's files.
export function createAuthenticatedApp({config, pool, provider = createGoogleProvider(config), store}) {
  const app = express();
  app.disable('x-powered-by');
  app.use(helmet());
  if (config.trustProxy) app.set('trust proxy', 1);
  app.use((req, res, next) => {
    res.set('Cache-Control', 'no-store');
    if (req.get('origin') === config.frontendUrl) {
      res.set('Access-Control-Allow-Origin', config.frontendUrl);
      res.set('Access-Control-Allow-Credentials', 'true');
      res.set('Access-Control-Allow-Headers', 'Content-Type, Accept');
      res.set('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS');
      res.vary('Origin');
    }
    if (req.method === 'OPTIONS') return res.sendStatus(req.get('origin') === config.frontendUrl ? 204 : 403);
    next();
  });
  const PgStore = connectPgSimple(session);
  app.use(session({name: config.cookieName, secret: config.secret,
    store: store || new PgStore({pool, tableName: 'auth_sessions', createTableIfMissing: false}),
    resave: false, saveUninitialized: false, rolling: false,
    cookie: {httpOnly: true, secure: config.secure, sameSite: 'lax', maxAge: config.ttlMs, path: '/'}}));
  const service = createAuthService({config, pool, provider, accountDirectory: authorizedAccounts(pool)});
  app.use('/api/auth', authRoutes(service, config));
  app.use('/api', requireAuth(service), (req, res, next) => {
      req.transportRole = req.user.role;
      // Only a server-owned foreign key can establish driver identity.
      req.auth = req.transportRole === 'driver' ? {driver_id: req.user.driver_id} : undefined;
      next();
  });
  app.get('/api/session', (req, res) => res.json({user: req.user, role: req.transportRole}));
  app.use('/api', (req, res, next) => ['GET', 'HEAD'].includes(req.method) ? next() : requireSameOrigin(config)(req, res, next));
  const authority = (req, res, next) => req.transportRole === 'authority' ? next() : res.status(403).json({error: 'Authority permission required'});
  const driver = (req, res, next) => req.transportRole === 'driver' ? next() : res.status(403).json({error: 'Driver permission required'});
  app.use('/api', (req, res, next) => {
    const isDriverEndpoint = /^\/drivers\/(me(?:\/trips)?|\d+\/trips)\/?$/.test(req.path)
      || /^\/trips\/\d+\/(start|stop)\/?$/.test(req.path);
    return (isDriverEndpoint ? driver : authority)(req, res, next);
  });
  // Never run the environment-based development identity on this entry point.
  app.use(createTransportApp(pool, {authenticateDriver: (req, res, next) => next(), authorizeManagement: authority}));
  app.use((error, req, res, next) => {
    if (res.headersSent) return next(error);
    if (error instanceof AuthError) return res.status(error.status).json({error: error.code});
    console.error('Authenticated transport request failed', {type: error.constructor.name, code: error.code});
    res.status(500).json({error: 'Authentication integration unavailable'});
  });
  return app;
}
