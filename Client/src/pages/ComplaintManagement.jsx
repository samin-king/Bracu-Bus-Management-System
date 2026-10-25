import {useEffect,useState} from 'react';
import {member4Api as api} from '../services/member4Api';
import {Messages,Pagination} from '../components/Member4State';
const statuses=['pending','in_review','resolved','rejected'];
export default function ComplaintManagement() {
 const [page,setPage]=useState(0);
 const [items,setItems]=useState([]),[filters,setFilters]=useState({status:'',category:'',search:''}),[detail,setDetail]=useState(null),[status,setStatus]=useState('pending'),[response,setResponse]=useState('');
 const [error,setError]=useState(''),[notice,setNotice]=useState(''),[busy,setBusy]=useState(false),[loading,setLoading]=useState(true);
 async function load(currentPage=page){setLoading(true);try{setItems(await api.manageComplaints({...Object.fromEntries(Object.entries(filters).filter(([,v])=>v)),limit:50,offset:currentPage*50}));setError('');}catch(e){setError(e.message);}finally{setLoading(false);}}
 useEffect(()=>{load();},[page]);
 async function open(id){try{const x=await api.manageComplaint(id);setDetail(x);setStatus(x.status);setResponse(x.response||'');setNotice('');}catch(e){setError(e.message);}}
 async function save(e){e.preventDefault();setBusy(true);setError('');try{const x=await api.updateComplaint(detail.id,{status,...(response.trim()?{response}: {})});setDetail(x);await load();setNotice('Complaint updated');}catch(e){setError(e.message);}finally{setBusy(false);}}
 return <section><h1 className="mb-6 text-3xl font-bold">Complaint management</h1><Messages error={error} notice={notice}/>
 <form onSubmit={e=>{e.preventDefault();setPage(0);load(0);}} className="mb-5 grid gap-4 rounded border bg-white p-5">
 <label>Status filter<select value={filters.status} onChange={e=>setFilters({...filters,status:e.target.value})}><option value="">All statuses</option>{statuses.map(x=><option key={x}>{x}</option>)}</select></label>
 <label>Category filter<select value={filters.category} onChange={e=>setFilters({...filters,category:e.target.value})}><option value="">All categories</option>{['service','driver','safety','schedule','other'].map(x=><option key={x}>{x}</option>)}</select></label>
 <label>Search complaints<input maxLength={250} value={filters.search} onChange={e=>setFilters({...filters,search:e.target.value})}/></label><button>Filter complaints</button></form>
 {loading?<p role="status">Loading complaints...</p>:!items.length?<p>No complaints found.</p>:items.map(x=><article key={x.id} className="my-3 rounded border bg-white p-4"><p>#{x.id} · {x.category} · {x.status}</p><p>{x.description}</p><button onClick={()=>open(x.id)}>Manage complaint #{x.id}</button></article>)}
 {detail&&<form onSubmit={save} className="my-5 grid gap-4 rounded border bg-white p-5"><h2 className="text-xl font-semibold">Manage complaint #{detail.id}</h2><p>Student: {detail.user_id}</p><p>{detail.description}</p><p>Trip: {detail.trip_id??'None'} · Route: {detail.route_id??'None'}</p>
 <label>Complaint status<select value={status} onChange={e=>setStatus(e.target.value)}>{statuses.map(x=><option key={x}>{x}</option>)}</select></label>
 <label>Authority response<textarea maxLength={5000} value={response} onChange={e=>setResponse(e.target.value)}/></label>
 <button disabled={busy} className="bg-blue-800 text-white">{busy?'Saving...':'Update complaint'}</button><button type="button" onClick={()=>setDetail(null)}>Close details</button></form>}
 <Pagination page={page} setPage={setPage} count={items.length} loading={loading}/></section>;
}
