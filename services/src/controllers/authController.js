import { AuthError } from '../services/authService.js';
const save = req => new Promise((resolve, reject) => req.session.save(error => error ? reject(error) : resolve()));
const regenerate = req => new Promise((resolve, reject) => req.session.regenerate(error => error ? reject(error) : resolve()));
export function createAuthController(service, config) {
  return {
    async google(req, res) {
      const { flow, url } = service.begin();
      await regenerate(req);
      req.session.oauth = flow;
      await save(req);
      res.redirect(url);
    },
    async callback(req, res) {
      const flow = req.session.oauth;
      delete req.session.oauth;
      await save(req);
      try {
        const user = await service.authenticate(req.query, flow);
        await regenerate(req);
        req.session.userId = user.id;
        req.session.authExpiresAt = Date.now() + config.ttlMs;
        await save(req);
        res.redirect(`${config.frontendUrl}/`);
      } catch (error) {
        if (error instanceof AuthError) return res.redirect(`${config.frontendUrl}/login?error=${encodeURIComponent(error.code)}`);
        throw error;
      }
    },
    me(req, res) { res.json(req.user); },
    async logout(req, res) {
      await new Promise((resolve, reject) => req.session.destroy(error => error ? reject(error) : resolve()));
      res.clearCookie(config.cookieName, { path: '/', httpOnly: true, sameSite: 'lax', secure: config.secure });
      res.status(204).end();
    }
  };
}
