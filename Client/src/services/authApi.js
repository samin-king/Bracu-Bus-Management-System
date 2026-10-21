async function request(path, options = {}) {
  const response = await fetch(`/api/auth${path}`, { credentials: 'include', cache: 'no-store', ...options });
  if (response.status === 401 && path === '/me') return null;
  if (!response.ok) throw new Error('Authentication is temporarily unavailable. Please try again.');
  return response.status === 204 ? null : response.json();
}
export const authApi = {
  login() { window.location.assign('/api/auth/google'); },
  me() { return request('/me'); },
  logout() { return request('/logout', { method: 'POST' }); }
};
