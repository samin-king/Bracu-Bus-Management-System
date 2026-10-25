export const DEV_STUDENT_EMAIL = 'saeeb.rahman.samin@g.bracu.ac.bd';
export const DEV_STUDENT_SUBJECT = 'local-development:member1-test-student';

export function localEmailLoginEnabled(env) {
  if (env.DEV_EMAIL_LOGIN !== 'true') return false;
  if (env.NODE_ENV !== 'development') throw new Error('DEV_EMAIL_LOGIN requires explicit NODE_ENV=development');
  const local = hostname => ['localhost', '127.0.0.1', '[::1]'].includes(hostname);
  const database = new URL(env.DATABASE_URL);
  const frontend = new URL(env.FRONTEND_URL);
  if (!['postgres:', 'postgresql:'].includes(database.protocol) || !local(database.hostname) ||
      !local(frontend.hostname) || !['http:', 'https:'].includes(frontend.protocol)) {
    throw new Error('DEV_EMAIL_LOGIN requires a loopback database and frontend');
  }
  return true;
}
