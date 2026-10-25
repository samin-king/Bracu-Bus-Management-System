import {useEffect,useState} from 'react';
import {member4Api as api} from '../services/member4Api';
import {Messages,Pagination} from '../components/Member4State';
export default function Feedback() {
 const [page,setPage]=useState(0);
 const [items,setItems]=useState([]),[target,setTarget]=useState('service'),[reference,setReference]=useState(''),[rating,setRating]=useState('5'),[comment,setComment]=useState('');
 const [error,setError]=useState(''),[notice,setNotice]=useState(''),[busy,setBusy]=useState(false),[loading,setLoading]=useState(true);
 async function load(currentPage=page){setLoading(true);try{setItems(await api.feedback(currentPage));setError('');}catch(e){setError(e.message);}finally{setLoading(false);}}
 useEffect(()=>{load();},[page]);
 async function submit(e){e.preventDefault();setBusy(true);setError('');setNotice('');try{await api.submitFeedback({target,rating:Number(rating),comment,...(target==='service'?{}:{[target+'_id']:reference})});setComment('');await load();setNotice('Feedback submitted');}catch(e){setError(e.message);}finally{setBusy(false);}}
 return <section><h1 className="mb-6 text-3xl font-bold">Feedback</h1><Messages error={error} notice={notice}/>
 <form onSubmit={submit} className="mb-8 grid gap-4 rounded-xl border bg-white p-5">
 <label>Feedback about<select value={target} onChange={e=>{setTarget(e.target.value);setReference('');}}>{['service','bus','trip','route'].map(x=><option key={x}>{x}</option>)}</select></label>
 {target!=='service'&&<label>{target} ID<input type="number" min="1" required value={reference} onChange={e=>setReference(e.target.value)}/></label>}
 <label>Rating<select value={rating} onChange={e=>setRating(e.target.value)}>{[1,2,3,4,5].map(n=><option key={n}>{n}</option>)}</select></label>
 <label>Comment (optional)<textarea maxLength={5000} value={comment} onChange={e=>setComment(e.target.value)}/></label>
 <button disabled={busy} className="bg-blue-800 text-white">{busy?'Submitting...':'Submit feedback'}</button></form>
 <h2 className="text-xl font-semibold">My feedback</h2><button onClick={()=>load()}>Refresh feedback</button>
 {loading?<p role="status">Loading feedback...</p>:!items.length?<p>No feedback found.</p>:items.map(x=><article key={x.id} className="my-3 rounded border bg-white p-4"><p>{x.target} · Rating: {x.rating}/5</p><p>{x.comment}</p><p>{new Date(x.created_at).toLocaleString()}</p></article>)}
 <Pagination page={page} setPage={setPage} count={items.length} loading={loading}/></section>;
}
