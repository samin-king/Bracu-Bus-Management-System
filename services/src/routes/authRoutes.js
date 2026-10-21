import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { createAuthController } from '../controllers/authController.js';
import { requireAuth, requireSameOrigin } from '../middleware/authMiddleware.js';
const wrap = fn => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
export function authRoutes(service, config) {
  const router = Router();
  const controller = createAuthController(service, config);
  const limiter = rateLimit({ windowMs: 600000, limit: 30, standardHeaders: 'draft-7', legacyHeaders: false,
    message: { error: 'too_many_attempts', message: 'Too many sign-in attempts. Try again later.' } });
  router.get('/google', limiter, wrap(controller.google));
  router.get('/google/callback', limiter, wrap(controller.callback));
  router.get('/me', requireAuth(service), controller.me);
  router.post('/logout', requireSameOrigin(config), wrap(controller.logout));
  return router;
}
