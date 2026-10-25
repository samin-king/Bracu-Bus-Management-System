import ManagementPage from '../components/ManagementPage';
import BusCard from '../components/BusCard';
import {busApi} from '../services/busApi';
const initial={bus_number:'',registration_number:'',capacity:37,status:'ACTIVE'};
const fields=[{name:'bus_number',label:'Bus number'},{name:'registration_number',label:'Registration number',optional:true},{name:'capacity',label:'Capacity',type:'number'},{name:'status',label:'Status',options:['ACTIVE','INACTIVE','MAINTENANCE']}];
export default function Buses(){return <ManagementPage title="Buses" api={busApi} Card={BusCard} fields={fields} initial={initial} toBody={x=>({...x,capacity:Number(x.capacity),registration_number:x.registration_number||null})}/>;}
