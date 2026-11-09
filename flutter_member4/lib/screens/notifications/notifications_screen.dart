import 'package:flutter/material.dart';
import '../../models/member4_models.dart';
import '../../state/member4_session.dart';
import '../../widgets/member4_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Member4Guard(title: 'Notifications',
      access: 'user', child: _NotificationsPage());
}
class _NotificationsPage extends StatefulWidget {
  const _NotificationsPage();
  @override
  State<_NotificationsPage> createState() => _NotificationsState();
}
class _NotificationsState extends Member4PageState<BusNotification, _NotificationsPage> {
  int unread = 0;
  @override
  Future<List<BusNotification>> fetch(int page) async {
    final api = Member4Session.of(context).api;
    final results = await Future.wait<dynamic>([api.notifications(page), api.unread()]);
    if (mounted) unread = results[1] as int;
    return results[0] as List<BusNotification>;
  }
  Future<void> mark([String? id]) async {
    final api = Member4Session.of(context).api;
    await act(() => id == null ? api.markAllRead() : api.markRead(id),
        id == null ? 'All notifications marked as read' : 'Notification marked as read');
  }
  void details(BusNotification item) {
    // There is no notification GET /:id; use the full list record.
    final origin = Member4Session.of(context);
    showDialog<void>(context: context, builder: (context) {
      final current = Member4Session.of(context);
      final sameSession = current.authenticated &&
        current.sessionKey == origin.sessionKey && current.api == origin.api;
      return AlertDialog(
      title: Text(sameSession ? item.title : 'Session changed'),
      content: sameSession ? SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [SelectableText(item.message), Text(item.isRead ? 'Read' : 'Unread'),
          Text('Created: ${displayDate(item.data['created_at'])}'),
          if (item.isRead) Text('Read: ${displayDate(item.data['read_at'])}'),
          if (item.data['reference_type'] != null)
            Text('Related ${item.data['reference_type']}: ${item.data['reference_id']}'),
        ])) : const Text('Close this notification to continue.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]);
    });
  }
  @override
  Widget build(BuildContext context) => layout('Notifications', [
    Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Unread: $unread',
      style: Theme.of(context).textTheme.titleLarge)),
    FilledButton(onPressed: busy || loading || unread == 0 ? null : () => mark(),
        child: const Text('Mark all as read')),
  ], items.map((x) => Card(child: Column(children: [
    ListTile(contentPadding: const EdgeInsets.all(16),
      leading: Icon(x.isRead ? Icons.mark_email_read : Icons.mark_email_unread,
        color: x.isRead ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.primary),
      title: Text(x.title, style: TextStyle(fontWeight: x.isRead ? FontWeight.normal : FontWeight.bold)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(x.message, maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8), Text(x.isRead ? 'Read' : 'Unread'),
        Text(displayDate(x.data['created_at'])),
      ]),
      onTap: busy || loading ? null : () => details(x)),
    if (!x.isRead) TextButton(onPressed: busy || loading ? null : () => mark(x.id),
        child: const Text('Mark as read')),
  ]))).toList(), emptyMessage: 'You have no notifications. Pull down to refresh.');
}
