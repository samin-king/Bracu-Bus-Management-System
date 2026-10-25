import {useEffect,useState} from 'react';
import {member4Api as api} from '../services/member4Api';
import {Messages,Pagination} from '../components/Member4State';
const initial={category:'service',description:'',trip_id:'',route_id:''};
export default function Complaints() {
 const [page,setPage]=useState(0);
 const [items,setItems]=useState([]),[detail,setDetail]=useState(null),[form,setForm]=useState(initial);
 const [error,setError]=useState(''),[notice,setNotice]=useState(''),[busy,setBusy]=useState(false),[loading,setLoading]=useState(true);
 async function load(currentPage=page){setLoading(true);try{setItems(await api.complaints(currentPage));setError('');}catch(e){setError(e.message);}finally{setLoading(false);}}
 useEffect(()=>{load();},[page]);
 async function submit(e){e.preventDefault();setBusy(true);setError('');setNotice('');try{await api.submitComplaint({...form,trip_id:form.trip_id||null,route_id:form.route_id||null});setForm(initial);await load();setNotice('Complaint submitted');}catch(e){setError(e.message);}finally{setBusy(false);}}
 async function open(id){try{setDetail(await api.complaint(id));}catch(e){setError(e.message);}}
 const field=(key,value)=>setForm({...form,[key]:value});
 return <section><h1 className="mb-6 text-3xl font-bold">Complaints</h1><Messages error={error} notice={notice}/>
 <form onSubmit={submit} className="mb-8 grid gap-4 rounded-xl border bg-white p-5">
 <h2 className="text-lg font-semibold">Submit a complaint</h2>
 <label>Category<select value={form.category} onChange={e=>field('category',e.target.value)}>{['service','driver','safety','schedule','other'].map(x=><option key={x}>{x}</option>)}</select></label>
 <label>Description<textarea required maxLength={5000} value={form.description} onChange={e=>field('description',e.target.value)}/></label>
 <label>Trip ID (optional)<input type="number" min="1" value={form.trip_id} onChange={e=>field('trip_id',e.target.value)}/></label>
 <label>Route ID (optional)<input type="number" min="1" value={form.route_id} onChange={e=>field('route_id',e.target.value)}/></label>
 <button disabled={busy} className="bg-blue-800 text-white">{busy?'Submitting...':'Submit complaint'}</button></form>
 <h2 className="text-xl font-semibold">My complaints</h2><button onClick={()=>load()}>Refresh complaints</button>
 {loading?<p role="status">Loading complaints...</p>:!items.length?<p>No complaints found.</p>:items.map(x=><article key={x.id} className="my-3 rounded border bg-white p-4"><p>#{x.id} · {x.category} · {x.status}</p><p>{x.description}</p><button onClick={()=>open(x.id)}>View complaint #{x.id}</button></article>)}
 {detail&&<article className="rounded border bg-white p-5"><h2 className="text-xl font-semibold">Complaint #{detail.id}</h2><p>{detail.category} · {detail.status}</p><p>{detail.description}</p><p>Trip: {detail.trip_id??'None'} · Route: {detail.route_id??'None'}</p><p>Submitted: {new Date(detail.created_at).toLocaleString()}</p><p>Response: {detail.response||'Awaiting response'}</p><button onClick={()=>setDetail(null)}>Close details</button></article>}
 <Pagination page={page} setPage={setPage} count={items.length} loading={loading}/></section>;
}
