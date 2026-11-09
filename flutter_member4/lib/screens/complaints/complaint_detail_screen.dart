import 'package:flutter/material.dart';
import '../../models/member4_models.dart';
import '../../state/member4_session.dart';
import '../../widgets/member4_widgets.dart';

class ComplaintDetailScreen extends StatelessWidget {
  const ComplaintDetailScreen({super.key, required this.id, this.management = false});
  final String id;
  final bool management;
  @override
  Widget build(BuildContext context) => Member4Guard(title: 'Complaint #$id',
    access: management ? 'management' : 'student',
    child: _DetailPage(key: ValueKey((id, management)), id: id, management: management));
}
class _DetailPage extends StatefulWidget {
  const _DetailPage({super.key, required this.id, required this.management});
  final String id;
  final bool management;
  @override
  State<_DetailPage> createState() => _DetailState();
}
class _DetailState extends Member4PageState<Complaint, _DetailPage> {
  final form = GlobalKey<FormState>();
  final response = TextEditingController();
  String status = 'pending';
  @override
  void dispose() { response.dispose(); super.dispose(); }
  @override
  Future<List<Complaint>> fetch(int page) async {
    final item = await Member4Session.of(context).api.complaint(widget.id, management: widget.management);
    if (mounted) { status = item.status; response.text = item.response ?? ''; }
    return [item];
  }
  Future<void> save() async {
    if (busy || loading || accessDenied || form.currentState?.validate() != true) return;
    final api = Member4Session.of(context).api;
    final current = items.single;
    final body = <String, dynamic>{
      if (status != current.status) 'status': status,
      if (response.text.trim().isNotEmpty && response.text.trim() != current.response)
        'response': response.text};
    if (body.isEmpty) {
      setState(() { notice = 'No changes to save'; error = null; });
      revealMessage();
      return;
    }
    await act(() async {
      final updated = await api.updateComplaint(widget.id, body);
      if (mounted) setState(() {
        items = [updated]; status = updated.status; response.text = updated.response ?? '';
      });
    }, 'Complaint updated', reload: false);
  }
  @override
  Widget build(BuildContext context) => layout('Complaint #${widget.id}', [],
    items.map((x) => SectionCard(title: 'Complaint #${x.id}', child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
        children: [Text(x.category), StatusBadge(x.status)]),
      const SizedBox(height: 12), SelectableText(x.description), const SizedBox(height: 16),
      if (widget.management) Text('Student: ${x.data['user_id']}'),
      Text('Trip: ${x.data['trip_id'] ?? 'None'} · Route: ${x.data['route_id'] ?? 'None'}'),
      Text('Submitted: ${displayDate(x.data['created_at'])}'),
      Text('Updated: ${displayDate(x.data['updated_at'])}'),
      const SizedBox(height: 16), Text('Response: ${x.response ?? 'Awaiting response'}'),
      if (widget.management) Form(key: form, child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        choiceField('Complaint status', status, statuses, (x) => setState(() => status = x)),
        textField('Authority response (optional)', response, lines: 4, maxLength: 5000, validator: (x) =>
          x == null || x.isEmpty ? null : requiredText(x)),
        const Text('An empty response preserves the existing response.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: busy || loading ? null : save, child: const Text('Update complaint')),
      ])),
    ]))).toList(), pagination: false);
}
