async function get(path) {
  const response = await fetch(`/api/student/transport${path}`, {credentials:'include',cache:'no-store'});
  const data = await response.json();
  if (!response.ok) throw new Error(response.status === 401 ? 'Your session has expired. Please sign in again.' : 'Transport schedule could not be loaded. Please retry.');
  return data;
}
export const transportApi = {
  routes: () => get('/routes'),
  pattern: id => get(`/patterns/${encodeURIComponent(id)}`),
  schedules: async filters => {
    const items = [];
    for (let page = 1; ; page++) {
      const result = await get('/schedules?' + new URLSearchParams({...filters,page,size:100}));
      items.push(...result.items);
      if (!result.hasMore) return items;
    }
  },
};
