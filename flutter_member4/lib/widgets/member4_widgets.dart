import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/member4_api.dart';
import '../state/member4_session.dart';

Widget choiceField(String label, String value, List<String> values,
    ValueChanged<String> onChanged) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: DropdownButtonFormField<String>(
    key: ValueKey((label, value)),
    // Supports hosts using Flutter 3.22+, before initialValue was introduced.
    // ignore: deprecated_member_use
    value: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label,
      border: const OutlineInputBorder()),
    items: values.map((x) => DropdownMenuItem(value: x,
      child: Text(x.isEmpty ? 'All' : x.replaceAll('_', ' ')))).toList(),
    onChanged: (x) { if (x != null) onChanged(x); },
  ),
);

Widget textField(String label, TextEditingController controller,
    {String? Function(String?)? validator, int lines = 1, bool numeric = false,
    int? maxLength}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: TextFormField(key: ValueKey(label), controller: controller,
    validator: validator, maxLines: lines, maxLength: maxLength,
    maxLengthEnforcement: MaxLengthEnforcement.none,
    buildCounter: (context, {required currentLength, required isFocused, required maxLength}) =>
      maxLength == null ? null : Text('${controller.text.length}/$maxLength'),
    autovalidateMode: AutovalidateMode.onUserInteraction,
    keyboardType: numeric ? TextInputType.number :
      (lines > 1 ? TextInputType.multiline : TextInputType.text),
    decoration: InputDecoration(labelText: label,
      alignLabelWithHint: lines > 1, border: const OutlineInputBorder())),
);

String displayDate(dynamic value) {
  if (value == null) return '—';
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '$value';
  String pad(int n) => '$n'.padLeft(2, '0');
  return '${pad(date.day)}/${pad(date.month)}/${date.year} '
      '${pad(date.hour)}:${pad(date.minute)}';
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      'resolved' => scheme.primary,
      'rejected' => scheme.error,
      'in_review' => scheme.tertiary,
      _ => scheme.secondary,
    };
    return Semantics(label: 'Status: ${status.replaceAll('_', ' ')}', child: Chip(
      avatar: Icon(switch (status) {
        'resolved' => Icons.check_circle_outline,
        'rejected' => Icons.cancel_outlined,
        'in_review' => Icons.manage_search,
        _ => Icons.schedule,
      }, size: 18, color: color),
      label: Text(status.replaceAll('_', ' '), style: TextStyle(color: color)),
      side: BorderSide(color: color), visualDensity: VisualDensity.compact));
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child,
    this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 20),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium)),
        const SizedBox(height: 16), child,
      ])));
}

/// Resets only on account, permission or API changes, not ordinary host rebuilds.
class Member4Guard extends StatelessWidget {
  const Member4Guard({super.key, required this.title, required this.access,
    required this.child});
  final String title;
  final String access;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final session = Member4Session.of(context);
    final allowed = session.authenticated && (switch (access) {
      'user' => true,
      'student' => session.student,
      'management' => session.management,
      _ => false,
    });
    return allowed ? KeyedSubtree(
      key: ValueKey((session.sessionKey, session.api, session.role)), child: child) :
      Scaffold(appBar: AppBar(title: Text(title)), body: SafeArea(child: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 40), const SizedBox(height: 16),
            Text(session.authenticated ? 'Insufficient permission' :
              'Authenticated user required', textAlign: TextAlign.center),
          ])))));
  }
}

/// Reads and mutations cannot overlap, preventing stale reads after a mutation.
abstract class Member4PageState<T, W extends StatefulWidget> extends State<W> {
  final scrollController = ScrollController();
  List<T> items = [];
  int page = 0;
  bool loading = true, busy = false;
  bool loadFailed = false, accessDenied = false;
  String? error, notice;
  bool _started = false, _startedRequest = false;
  int _retryPage = 0;
  Future<List<T>> fetch(int page);
  @override
  void dispose() { scrollController.dispose(); super.dispose(); }
  void revealMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scrollController.hasClients) {
        scrollController.animateTo(0, duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut);
      }
    });
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) { _started = true; load(); }
  }
  void _failure(Object exception) {
    error = exception is Member4Exception ? exception.message :
      'Something went wrong. Please try again.';
    if (exception is Member4Exception &&
        (exception.status == 401 || exception.status == 403)) {
      accessDenied = true;
    }
    if (accessDenied) { items = []; notice = null; }
  }
  Future<void> load({int? target}) async {
    if ((loading && _startedRequest) || !mounted) return;
    _startedRequest = true;
    final nextPage = target ?? page;
    _retryPage = nextPage;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() { loading = true; error = null; loadFailed = false; });
    try {
      final result = await fetch(nextPage);
      if (!mounted) return;
      setState(() { items = result; page = nextPage; accessDenied = false; });
      if (target != null) revealMessage();
    } catch (e) {
      if (mounted) setState(() { loadFailed = true; _failure(e); });
      if (mounted) revealMessage();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  Future<void> act(Future<void> Function() action, String success,
      {bool reload = true, int? target}) async {
    if (busy || loading || accessDenied) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() { busy = true; error = null; notice = null; });
    try {
      await action();
      if (!mounted) return;
      setState(() => notice = success);
      if (reload) await load(target: target);
    } catch (e) {
      if (mounted) setState(() => _failure(e));
    } finally {
      if (mounted) { setState(() => busy = false); revealMessage(); }
    }
  }
  Widget _message(BuildContext context, String message, {required bool failure}) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(liveRegion: true, child: Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
        color: failure ? scheme.errorContainer : scheme.primaryContainer),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(failure ? Icons.error_outline : Icons.check_circle_outline,
          color: failure ? scheme.onErrorContainer : scheme.onPrimaryContainer),
        const SizedBox(width: 12), Expanded(child: Text(message, style: TextStyle(
          color: failure ? scheme.onErrorContainer : scheme.onPrimaryContainer))),
      ])));
  }
  Widget layout(String title, List<Widget> content, List<Widget> rows,
      {bool pagination = true, String emptyMessage = 'No records found.'}) => Scaffold(
    appBar: AppBar(title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      actions: [IconButton(tooltip: 'Refresh',
        onPressed: loading || busy ? null : () => load(), icon: const Icon(Icons.refresh))]),
    body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
      final inset = constraints.maxWidth > 792 ? (constraints.maxWidth - 760) / 2 : 16.0;
      return RefreshIndicator(onRefresh: () async { if (!busy) await load(); },
        child: ListView(controller: scrollController,
          padding: EdgeInsets.fromLTRB(inset, 16, inset, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(), children: [
            if (error != null) _message(context, error!, failure: true),
            if (notice != null) _message(context, notice!, failure: false),
            if (!accessDenied) ExcludeFocus(excluding: busy || loading,
              child: AbsorbPointer(absorbing: busy || loading,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content))),
            if (busy) const LinearProgressIndicator(semanticsLabel: 'Saving'),
            if (loading) const Padding(padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'))),
            if (loadFailed) Align(alignment: Alignment.centerLeft, child: TextButton.icon(
              onPressed: loading || busy ? null : () => load(target: _retryPage),
              icon: const Icon(Icons.refresh), label: const Text('Retry'))),
            if (!loading && !accessDenied) ...[
              if (items.isEmpty && !loadFailed) Padding(padding: const EdgeInsets.all(24),
                child: Column(children: [const Icon(Icons.inbox_outlined, size: 40),
                  const SizedBox(height: 12), Text(emptyMessage, textAlign: TextAlign.center)]))
              else ExcludeFocus(excluding: busy, child: AbsorbPointer(absorbing: busy,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows))),
            ],
            if (pagination && !accessDenied) Padding(padding: const EdgeInsets.only(top: 16),
              child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12, runSpacing: 8, children: [
                  TextButton(onPressed: loading || busy || page == 0 ? null :
                    () => load(target: page - 1), child: const Text('Previous')),
                  Text('Page ${page + 1}'),
                  TextButton(onPressed: loading || busy || loadFailed || items.length < 50 ? null :
                    () => load(target: page + 1), child: const Text('Next')),
                ])),
          ]));
    })));
}
