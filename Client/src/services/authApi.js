async function request(path, options = {}) {
  const response = await fetch(`/api/auth${path}`, { credentials: 'include', cache: 'no-store', ...options });
  if (response.status === 401 && path === '/me') return null;
  if (!response.ok) {const error=new Error('Authentication is temporarily unavailable. Please try again.');error.status=response.status;throw error;}
  return response.status === 204 ? null : response.json();
}
export const authApi = {
  async requestEmail(email) {
    const options={method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email})};
    if (import.meta.env.DEV && ['localhost','127.0.0.1','[::1]'].includes(window.location.hostname)) {
      try {return await request('/development/email-login',options);}
      catch(error) {if(error.status!==404) throw error;}
    }
    return request('/email',options);
  },
  verifyEmail(token) {return request('/email/verify',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({token})});},
  me() { return request('/me'); },
  logout() { return request('/logout', { method: 'POST' }); }
};
