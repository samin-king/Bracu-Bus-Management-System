import { afterEach, expect, it, vi } from 'vitest';
import { authApi } from '../services/authApi.js';
afterEach(() => vi.unstubAllGlobals());
it('me sends cookie credentials and treats 401 as anonymous', async () => {
  const fetch = vi.fn().mockResolvedValue({ status: 401 });
  vi.stubGlobal('fetch', fetch);
  expect(await authApi.me()).toBeNull();
  expect(fetch).toHaveBeenCalledWith('/api/auth/me', expect.objectContaining({ credentials: 'include', cache: 'no-store' }));
});
it('logout uses POST and propagates failures', async () => {
  const fetch = vi.fn().mockResolvedValue({ status: 500, ok: false });
  vi.stubGlobal('fetch', fetch);
  await expect(authApi.logout()).rejects.toThrow('temporarily unavailable');
  expect(fetch).toHaveBeenCalledWith('/api/auth/logout', expect.objectContaining({ method: 'POST', credentials: 'include' }));
});
it('logout accepts a no-content response', async () => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ status: 204, ok: true }));
  expect(await authApi.logout()).toBeNull();
});