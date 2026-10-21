export function loadAuthConfig(env = process.env) {
  for (const key of ['DATABASE_URL', 'GOOGLE_CALLBACK_URL', 'FRONTEND_URL', 'SESSION_SECRET']) {
    if (!env[key]?.trim()) throw new Error(`Missing configuration: ${key}`);
  }
  if (env.SESSION_SECRET.length < 32 || env.SESSION_SECRET.startsWith('replace-')) throw new Error('SESSION_SECRET must be random and at least 32 characters');
  const production = env.NODE_ENV === 'production';
  const hasClientId = Boolean(env.GOOGLE_CLIENT_ID?.trim());
  const hasClientSecret = Boolean(env.GOOGLE_CLIENT_SECRET?.trim());
  if (hasClientId !== hasClientSecret || (production && !hasClientId)) throw new Error('Google OAuth credentials must both be configured');
  for (const key of ['FRONTEND_URL', 'GOOGLE_CALLBACK_URL']) {
    const url = new URL(env[key]);
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || (production && url.protocol !== 'https:')) throw new Error(`Invalid URL: ${key}`);
  }
  const domain = (env.BRACU_STUDENT_EMAIL_DOMAIN || 'g.bracu.ac.bd').toLowerCase();
  if (!/^[a-z0-9]+(?:[.-][a-z0-9]+)*\.[a-z]{2,}$/.test(domain)) throw new Error('Invalid institutional domain');
  const ttlHours = Number(env.SESSION_TTL_HOURS || 8);
  if (!Number.isFinite(ttlHours) || ttlHours <= 0 || ttlHours > 24) throw new Error('SESSION_TTL_HOURS must be greater than zero and at most 24');
  const secure = env.SESSION_COOKIE_SECURE === 'true' || production;
  return {
    databaseUrl: env.DATABASE_URL, clientId: env.GOOGLE_CLIENT_ID, clientSecret: env.GOOGLE_CLIENT_SECRET,
    callbackUrl: env.GOOGLE_CALLBACK_URL, frontendUrl: new URL(env.FRONTEND_URL).origin,
    domain, emailPattern: env.BRACU_STUDENT_EMAIL_PATTERN ? new RegExp(`^(?:${env.BRACU_STUDENT_EMAIL_PATTERN})$`, 'i') : null,
    secret: env.SESSION_SECRET, ttlMs: ttlHours * 3600000, secure, trustProxy: env.TRUST_PROXY === 'true',
    cookieName: secure ? '__Host-bracu.sid' : 'bracu.sid'
  };
}
