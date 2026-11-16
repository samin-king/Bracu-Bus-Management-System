import 'package:flutter/material.dart';
import '../demo/demo_store.dart';
import '../services/api_client.dart';
import 'transport_theme.dart';

class PremiumDashboardContent extends StatelessWidget {
  const PremiumDashboardContent({super.key,required this.store,required this.role,required this.open});
  final DemoStore store;final TransportRole role;final ValueChanged<String> open;
  @override
  Widget build(BuildContext context)=>LayoutBuilder(builder:(context,bounds){
    final metrics=<({String label,String value,IconData icon,String hint})>[
      (label:'Total buses',value:'${store.tables['buses']!.length}',icon:Icons.directions_bus_outlined,hint:'Connected campus fleet'),
      (label:role==TransportRole.authority?'Total drivers':'Connected routes',value:'${store.tables[role==TransportRole.authority?'drivers':'routes']!.length}',icon:role==TransportRole.authority?Icons.badge_outlined:Icons.alt_route_rounded,hint:role==TransportRole.authority?'People behind the journey':'Your city, closer to campus'),
      (label:role==TransportRole.driver?'Assigned trips':'Scheduled trips',value:'${store.tables['trips']!.where((t)=>role==TransportRole.driver?t['driver_id']==1:t['status']=='SCHEDULED').length}',icon:Icons.calendar_month_outlined,hint:role==TransportRole.driver?'Your current assignments':'Upcoming campus departures'),
      (label:role==TransportRole.student?'My bookings':role==TransportRole.authority?'Total routes':'Booked passengers',
        value:role==TransportRole.student?'${store.tables['bookings']!.where((b)=>b['student_id']==1&&b['status']=='CONFIRMED').length}':role==TransportRole.authority?'${store.tables['routes']!.length}':'${store.tables['bookings']!.where((b)=>b['status']=='CONFIRMED'&&store.record('trips',b['trip_id'] as int)['driver_id']==1).fold<int>(0,(n,b)=>n+(b['seats'] as int))}',
        icon:role==TransportRole.authority?Icons.route_outlined:Icons.confirmation_number_outlined,hint:role==TransportRole.student?'Your reserved demo journeys':role==TransportRole.authority?'Routes across the city':'Seats on your assigned trips'),
    ];
    final columns=bounds.maxWidth>=1000?4:bounds.maxWidth>=540?2:1;
    final tileWidth=(bounds.maxWidth-(columns-1)*16)/columns;
    final actions=switch(role){TransportRole.student=>['Bus Booking','Booking History','Complaints','Notifications'],TransportRole.driver=>['Assigned Trips','Trip Schedule','Passenger List','Driver Profile'],_=>['Bus Management','Driver Assignment','Trip Management','Complaints Management']};
    return SingleChildScrollView(padding:const EdgeInsets.fromLTRB(0,4,0,28),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _hero(context,bounds.maxWidth),const SizedBox(height:22),
      Wrap(spacing:16,runSpacing:16,children:[for(final metric in metrics)SizedBox(width:tileWidth,child:HoverCard(child:Padding(padding:const EdgeInsets.all(21),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:const Color(0xffeef3ff),borderRadius:BorderRadius.circular(10)),child:Icon(metric.icon,size:19,color:TransportColors.blue)),const Spacer(),const Icon(Icons.north_east_rounded,size:14,color:Color(0xffbcc7d6))]),
        const SizedBox(height:19),Text(metric.value,style:const TextStyle(fontSize:30,fontWeight:FontWeight.w700,letterSpacing:-1.2)),
        const SizedBox(height:3),Text(metric.label,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:12)),const SizedBox(height:6),Text(metric.hint,style:const TextStyle(fontSize:9,color:TransportColors.muted)),
      ]))))]),
      const SizedBox(height:27),
      _section('Your workspace','Everything you need for a smoother journey.'),const SizedBox(height:14),
      Wrap(spacing:14,runSpacing:14,children:[for(final name in actions)SizedBox(width:(bounds.maxWidth-(columns-1)*14)/columns,child:Semantics(button:true,label:'Open $name',onTap:()=>open(name),excludeSemantics:true,
        child:HoverCard(onTap:()=>open(name),child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(moduleIcon(name),size:24,color:TransportColors.blue),const SizedBox(height:18),Text(name,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:12)),const SizedBox(height:7),
          Row(children:[const Text('Explore module',style:TextStyle(fontSize:10,color:TransportColors.muted)),const Spacer(),const Icon(Icons.arrow_forward_rounded,size:16,color:TransportColors.blue)]),
        ])))))]),
      const SizedBox(height:27),
      if(bounds.maxWidth>=850)Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:3,child:_departures(context)),const SizedBox(width:20),Expanded(flex:2,child:_community(context))])
      else ...[_departures(context),const SizedBox(height:18),_community(context)],
    ]));
  });

  Widget _hero(BuildContext context,double width)=>Container(padding:EdgeInsets.all(width<500?22:29),
    decoration:BoxDecoration(color:TransportColors.navy,borderRadius:BorderRadius.circular(20)),
    child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('BRACU COMMUNITY  /  CAMPUS CONNECTED',style:TextStyle(fontSize:8,color:TransportColors.gold,letterSpacing:1.4,fontWeight:FontWeight.w600)),
      const SizedBox(height:15),
      Text(switch(role){TransportRole.student=>'Good to see you, ${'${store.profile['name']}'.split(' ').first}.',TransportRole.driver=>'Ready for your next journey?',_=>'Keep campus moving.'},style:TextStyle(color:Colors.white,fontSize:width<500?24:31,fontWeight:FontWeight.w700,letterSpacing:-.8)),
      const SizedBox(height:10),
      Text(switch(role){TransportRole.student=>'Your routes, bookings and campus updates. All in one place.',TransportRole.driver=>'A clear view of your trips, passengers and the road ahead.',_=>'Your transport network, thoughtfully connected in one workspace.'},style:const TextStyle(color:Color(0xffb5c5da),fontSize:11,height:1.7)),
      const SizedBox(height:18),
      Row(mainAxisSize:MainAxisSize.min,children:[Container(width:5,height:5,decoration:const BoxDecoration(color:TransportColors.gold,shape:BoxShape.circle)),const SizedBox(width:7),const Flexible(child:Text('Local demonstration · Synthetic data only',style:TextStyle(fontSize:9,color:Color(0xffd0dcee))))]),
    ])),if(width>650)...[const SizedBox(width:20),Icon(Icons.directions_bus_filled_rounded,size:100,color:Colors.white.withValues(alpha:.10)),const SizedBox(width:12)],
  ]));
  Widget _section(String title,String subtitle)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w600,letterSpacing:-.3)),const SizedBox(height:5),Text(subtitle,style:const TextStyle(fontSize:10,color:TransportColors.muted))]);
  Widget _departures(BuildContext context) {
    final trips=store.tables['trips']!.where((t)=>role==TransportRole.driver?t['driver_id']==1:t['status']=='SCHEDULED').take(3).map(store.joinedTrip).toList();
    return Card(child:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[const Expanded(child:Text('Upcoming journeys',style:TextStyle(fontSize:15,fontWeight:FontWeight.w600))),TextButton(onPressed:()=>open(role==TransportRole.student?'Bus Booking':role==TransportRole.driver?'Trip Schedule':'Trip Management'),child:const Text('View all'))]),
      const SizedBox(height:8),
      if(trips.isEmpty)const Padding(padding:EdgeInsets.all(16),child:Text('No upcoming journeys.',style:TextStyle(color:TransportColors.muted))),
      for(final trip in trips)Padding(padding:const EdgeInsets.symmetric(vertical:13),child:Row(children:[
        Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:const Color(0xfff0f4fb),borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.directions_bus_outlined,color:TransportColors.blue,size:19)),
        const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${(trip['route'] as Map)['route_name']}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600)),const SizedBox(height:4),Text('${(trip['bus'] as Map)['bus_number']} · ${trip['travel_date']}',style:const TextStyle(fontSize:9,color:TransportColors.muted))])),
        const SizedBox(width:8),Text('${trip['departure_time']}'.substring(0,5),style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),
      ])),
    ])));
  }
  Widget _community(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(23),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:const Color(0xfffff5db),borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.school_outlined,color:Color(0xff9c7c30),size:22)),const SizedBox(width:11),const Expanded(child:Text('A connected campus',style:TextStyle(fontSize:14,fontWeight:FontWeight.w600)))]),
    const SizedBox(height:18),Text(role==TransportRole.student?'Make room for a better day.':'Every journey matters.',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w600,letterSpacing:-.4)),
    const SizedBox(height:9),Text(switch(role){TransportRole.student=>'Reserve your seat, check your route and stay up to date with your university community.',TransportRole.driver=>'Your work connects our community. Check assignments and keep passengers informed.',_=>'Coordinate people, routes and schedules with clarity. A thoughtful commute starts with you.'},style:const TextStyle(fontSize:11,height:1.8,color:TransportColors.muted)),
    const SizedBox(height:19),const Divider(height:1),const SizedBox(height:14),
    Row(children:[const Icon(Icons.shield_outlined,size:15,color:TransportColors.blue),const SizedBox(width:7),const Expanded(child:Text('Synthetic records. Real possibilities.',style:TextStyle(fontSize:9,color:TransportColors.muted)))]),
  ])));
}
