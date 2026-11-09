import 'package:flutter/material.dart';
import '../../models/member4_models.dart';
import '../../state/member4_session.dart';
import '../../widgets/member4_widgets.dart';
import 'complaint_detail_screen.dart';

class ComplaintManagementScreen extends StatelessWidget {
  const ComplaintManagementScreen({super.key});
  @override
  Widget build(BuildContext context) => const Member4Guard(title: 'Complaint management',
      access: 'management', child: _ManagementPage());
}
class _ManagementPage extends StatefulWidget {
  const _ManagementPage();
  @override
  State<_ManagementPage> createState() => _ManagementState();
}
class _ManagementState extends Member4PageState<Complaint, _ManagementPage> {
  final form = GlobalKey<FormState>();
  final search = TextEditingController();
  String status = '', category = '';
  Map<String, String> filters = {};
  @override
  void dispose() { search.dispose(); super.dispose(); }
  @override
  Future<List<Complaint>> fetch(int page) => Member4Session.of(context).api
      .complaints(page, management: true, filters: filters);
  @override
  Widget build(BuildContext context) => layout('Complaint management', [
    SectionCard(title: 'Find complaints', child: Form(key: form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      choiceField('Status filter', status, ['', ...statuses], (x) => setState(() => status = x)),
      choiceField('Category filter', category, ['', ...categories], (x) => setState(() => category = x)),
      textField('Search complaints', search, maxLength: 250, validator: (x) =>
          (x?.length ?? 0) > 250 ? 'Use at most 250 characters' : null),
      FilledButton(onPressed: busy || loading ? null : () {
        if (form.currentState?.validate() != true) return;
        filters = {if (status.isNotEmpty) 'status': status,
          if (category.isNotEmpty) 'category': category,
          if (search.text.trim().isNotEmpty) 'search': search.text};
        load(target: 0);
      }, child: const Text('Filter complaints')),
    ]))),
  ], items.map((x) => Card(child: InkWell(borderRadius: BorderRadius.circular(12),
    onTap: busy || loading ? null : () async {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
        ComplaintDetailScreen(id: x.id, management: true)));
      if (mounted) await load();
    }, child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('#${x.id} · ${x.category}', style: Theme.of(context).textTheme.titleMedium),
          StatusBadge(x.status),
        ]),
        Text(x.description, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8), const Text('Manage complaint'),
      ]))))).toList(), emptyMessage: 'No complaints match these filters.');
}
