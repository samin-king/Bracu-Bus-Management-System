import 'package:flutter/material.dart';
import '../../models/member4_models.dart';
import '../../state/member4_session.dart';
import '../../widgets/member4_widgets.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});
  @override
  Widget build(BuildContext context) => const Member4Guard(title: 'Feedback',
      access: 'student', child: _FeedbackPage());
}
class _FeedbackPage extends StatefulWidget {
  const _FeedbackPage();
  @override
  State<_FeedbackPage> createState() => _FeedbackState();
}
class _FeedbackState extends Member4PageState<FeedbackEntry, _FeedbackPage> {
  final form = GlobalKey<FormState>();
  final reference = TextEditingController(), comment = TextEditingController();
  String target = 'service', rating = '5';
  @override
  void dispose() { reference.dispose(); comment.dispose(); super.dispose(); }
  @override
  Future<List<FeedbackEntry>> fetch(int page) => Member4Session.of(context).api.feedback(page);
  Future<void> submit() async {
    if (busy || loading || accessDenied || form.currentState?.validate() != true) return;
    final api = Member4Session.of(context).api;
    final body = <String, dynamic>{'target': target, 'rating': int.parse(rating),
      'comment': comment.text,
      if (target != 'service') '${target}_id': int.parse(reference.text)};
    await act(() async {
      await api.submitFeedback(body);
      if (mounted) comment.clear();
    }, 'Feedback submitted', target: 0);
  }
  @override
  Widget build(BuildContext context) => layout('Feedback', [
    SectionCard(title: 'Share your feedback', subtitle: 'Rate your experience from 1 (poor) to 5 (excellent).',
      child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      choiceField('Feedback about', target, targets, (x) => setState(() {
        target = x; reference.clear();
      })),
      if (target != 'service') textField('$target ID', reference, numeric: true,
          validator: (x) => referenceId(x, required: true)),
      choiceField('Rating', rating, ['1', '2', '3', '4', '5'], (x) => setState(() => rating = x)),
      textField('Comment (optional)', comment, lines: 4, maxLength: 5000, validator: (x) =>
        x == null || x.isEmpty ? null : requiredText(x)),
      FilledButton(onPressed: busy || loading ? null : submit, child: const Text('Submit feedback')),
    ]))),
    Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('My feedback',
      style: Theme.of(context).textTheme.titleLarge)),
  ], items.map((x) => Card(child: ListTile(
    title: Text('${x.data['target']} · Rating: ${x.data['rating']}/5'),
    subtitle: Text('${x.data['comment'] ?? ''}\n${displayDate(x.data['created_at'])}'),
  ))).toList(), emptyMessage: 'No feedback yet. Your ratings will appear here.');
}
