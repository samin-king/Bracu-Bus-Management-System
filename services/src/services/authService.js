import { OAuth2Client } from 'google-auth-library';
import { randomBytes, createHash, timingSafeEqual } from 'node:crypto';
export class AuthError extends Error {
  constructor(code, status = 401) { super(code); this.code = code; this.status = status; }
}
export const randomToken = () => randomBytes(32).toString('base64url');
export function equalToken(a, b) {
  return typeof a === 'string' && typeof b === 'string' && Buffer.byteLength(a) === Buffer.byteLength(b) && timingSafeEqual(Buffer.from(a), Buffer.from(b));
}
export function validateIdentity(claims, config) {
  const email = typeof claims?.email === 'string' ? claims.email.toLowerCase() : '';
  if (!claims?.sub || typeof claims.sub !== 'string' || claims.sub.length > 255) throw new AuthError('google_failed');
  const [localPart, domain] = email.split('@');
  // Student names contain 2-8 alphabetic components; the email local part is at most 64 characters.
  // This is an eligibility check on Google's verified claims, never proof of identity by itself.
  if (claims.email_verified !== true || typeof claims.hd !== 'string' || claims.hd.toLowerCase() !== config.domain ||
      !/^[a-z]+(?:\.[a-z]+){1,7}@[a-z0-9.-]+$/.test(email) ||
      domain !== config.domain || localPart.length > 64 || email.length > 254 ||
      (config.emailPattern && !config.emailPattern.test(email))) throw new AuthError('invalid_institution', 403);
  return { subject: claims.sub, email, name: String(claims.name || email.split('@')[0]).slice(0, 255) };
}
export function createGoogleProvider(config) {
  if (!config.clientId?.trim() || !config.clientSecret?.trim()) {
    const unavailable = () => { throw new AuthError('oauth_not_configured', 503); };
    return { authorizationUrl: unavailable, verify: unavailable };
  }
  const client = new OAuth2Client(config.clientId, config.clientSecret, config.callbackUrl);
  return {
    authorizationUrl({ state, nonce, verifier }) {
      return client.generateAuthUrl({ scope: ['openid', 'email', 'profile'], state, nonce,
        hd: config.domain, prompt: 'select_account', code_challenge_method: 'S256',
        code_challenge: createHash('sha256').update(verifier).digest('base64url') });
    },
    async verify(code, verifier) {
      const { tokens } = await client.getToken({ code, codeVerifier: verifier, redirect_uri: config.callbackUrl });
      if (!tokens.id_token) throw new AuthError('google_failed');
      const ticket = await client.verifyIdToken({ idToken: tokens.id_token, audience: config.clientId });
      return ticket.getPayload();
    }
  };
}
export function createAuthService({ pool, provider, config }) {
  return {
    begin() {
      const flow = { state: randomToken(), nonce: randomToken(), verifier: randomToken(), createdAt: Date.now() };
      return { flow, url: provider.authorizationUrl(flow) };
    },
    async authenticate(query, flow) {
      if (!flow || typeof query.state !== 'string' || !equalToken(query.state, flow.state) || Date.now() - flow.createdAt > 600000) throw new AuthError('invalid_callback', 400);
      if (query.error) throw new AuthError('google_denied');
      if (typeof query.code !== 'string' || !query.code || query.code.length > 4096) throw new AuthError('invalid_callback', 400);
      let claims;
      try { claims = await provider.verify(query.code, flow.verifier); }
      catch { throw new AuthError('google_failed'); }
      if (!equalToken(claims?.nonce, flow.nonce)) throw new AuthError('invalid_callback', 400);
      const identity = validateIdentity(claims, config);
      try {
        const result = await pool.query(`INSERT INTO users (google_subject, name, email, role)
          VALUES ($1, $2, $3, 'student') ON CONFLICT (google_subject) DO UPDATE
          SET name = EXCLUDED.name, email = EXCLUDED.email, updated_at = NOW()
          WHERE users.role = 'student' RETURNING id, name, email, role`, [identity.subject, identity.name, identity.email]);
        if (!result.rows[0]) throw new AuthError('invalid_institution', 403);
        return result.rows[0];
      } catch (error) {
        if (error.code === '23505') throw new AuthError('account_conflict', 403);
        throw error;
      }
    },
    async findUser(id) {
      const result = await pool.query("SELECT id, name, email, role FROM users WHERE id = $1 AND role = 'student'", [id]);
      return result.rows[0] || null;
    }
  };
}
