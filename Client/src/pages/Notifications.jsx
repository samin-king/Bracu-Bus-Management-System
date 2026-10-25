import {useEffect,useState} from 'react';
import {member4Api as api} from '../services/member4Api';
import {Messages,Pagination} from '../components/Member4State';
export default function Notifications() {
 const [page,setPage]=useState(0);
 const [items,setItems]=useState([]),[count,setCount]=useState(0),[error,setError]=useState(''),[notice,setNotice]=useState(''),[busy,setBusy]=useState(false),[loading,setLoading]=useState(true);
 async function load(currentPage=page){setLoading(true);try{const [list,unread]=await Promise.all([api.notifications(currentPage),api.unread()]);setItems(list);setCount(unread.count);setError('');}catch(e){setError(e.message);}finally{setLoading(false);}}
 useEffect(()=>{load();},[page]);
 async function mark(id){setBusy(true);try{if(id)await api.markRead(id);else await api.markAllRead();await load();setNotice(id?'Notification marked as read':'All notifications marked as read');}catch(e){setError(e.message);}finally{setBusy(false);}}
 return <section><h1 className="mb-6 text-3xl font-bold">Notifications</h1><Messages error={error} notice={notice}/><p>Unread: {count}</p>
 <button onClick={()=>load()}>Refresh notifications</button><button disabled={busy||!count} onClick={()=>mark()}>Mark all as read</button>
 {loading?<p role="status">Loading notifications...</p>:!items.length?<p>No notifications found.</p>:items.map(x=><article key={x.id} className="my-3 rounded border bg-white p-4"><h2 className="text-lg font-semibold">{x.title}</h2><p>{x.message}</p><p>{x.read_at?'Read':'Unread'} · {new Date(x.created_at).toLocaleString()}</p>{x.reference_type&&<p>Related {x.reference_type}: {x.reference_id}</p>}{!x.read_at&&<button disabled={busy} onClick={()=>mark(x.id)}>Mark as read</button>}</article>)}
 <Pagination page={page} setPage={setPage} count={items.length} loading={loading}/></section>;
}
