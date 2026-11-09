import 'package:flutter/material.dart';
import '../../models/member4_models.dart';
import '../../state/member4_session.dart';
import '../../widgets/member4_widgets.dart';
import 'complaint_detail_screen.dart';

class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Member4Guard(title: 'Complaints',
      access: 'student', child: _ComplaintsPage());
}
class _ComplaintsPage extends StatefulWidget {
  const _ComplaintsPage();
  @override
  State<_ComplaintsPage> createState() => _ComplaintsState();
}
class _ComplaintsState extends Member4PageState<Complaint, _ComplaintsPage> {
  final form = GlobalKey<FormState>();
  final description = TextEditingController(), trip = TextEditingController(),
      route = TextEditingController();
  String category = 'service';
  @override
  void dispose() { description.dispose(); trip.dispose(); route.dispose(); super.dispose(); }
  @override
  Future<List<Complaint>> fetch(int page) => Member4Session.of(context).api.complaints(page);
  Future<void> submit() async {
    if (busy || loading || accessDenied || form.currentState?.validate() != true) return;
    final api = Member4Session.of(context).api;
    final body = <String, dynamic>{'category': category, 'description': description.text,
      'trip_id': trip.text.isEmpty ? null : int.parse(trip.text),
      'route_id': route.text.isEmpty ? null : int.parse(route.text)};
    await act(() async {
      await api.submitComplaint(body);
      if (!mounted) return;
      description.clear(); trip.clear(); route.clear();
      form.currentState?.reset();
    }, 'Complaint submitted', target: 0);
  }
  @override
  Widget build(BuildContext context) => layout('Complaints', [
    SectionCard(title: 'Submit a complaint', subtitle: 'Tell us what happened so the transport team can help.',
      child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      choiceField('Category', category, categories, (x) => setState(() => category = x)),
      textField('Description', description, validator: requiredText, lines: 4, maxLength: 5000),
      textField('Trip ID (optional)', trip, validator: referenceId, numeric: true),
      textField('Route ID (optional)', route, validator: referenceId, numeric: true),
      FilledButton(onPressed: busy || loading ? null : submit, child: const Text('Submit complaint')),
    ]))),
    Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('My complaints',
      style: Theme.of(context).textTheme.titleLarge)),
  ], items.map((x) => Card(child: InkWell(borderRadius: BorderRadius.circular(12),
    onTap: busy || loading ? null : () async {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
        ComplaintDetailScreen(id: x.id)));
      if (mounted) await load();
    }, child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('#${x.id} · ${x.category}', style: Theme.of(context).textTheme.titleMedium),
          StatusBadge(x.status),
        ]),
        Text(x.description, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8), Text('Submitted: ${displayDate(x.data['created_at'])}'),
        const SizedBox(height: 8), const Text('View complaint details'),
      ]))))).toList(), emptyMessage: 'No complaints yet. Your submissions will appear here.');
}
