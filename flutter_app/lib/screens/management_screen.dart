import 'package:flutter/material.dart';

import '../models/transport_record.dart';
import '../services/api_client.dart';
import '../services/resource_service.dart';
import '../widgets/async_body.dart';
import '../widgets/record_card.dart';
import '../widgets/role_gate.dart';
import 'record_form.dart';

class ManagementScreen<T extends TransportRecord> extends StatelessWidget {
  const ManagementScreen({
    super.key,
    required this.service,
    required this.title,
    required this.kind,
    this.enableTools = false,
  });
  final ResourceService<T> service;
  final String title, kind;
  final bool enableTools;
  @override
  Widget build(BuildContext context) => RoleGate(
    api: service.api,
    role: TransportRole.authority,
    builder: (_) => _ManagementBody<T>(
      service: service,
      title: title,
      kind: kind,
      enableTools: enableTools,
    ),
  );
}

class _ManagementBody<T extends TransportRecord> extends StatefulWidget {
  const _ManagementBody({
    required this.service,
    required this.title,
    required this.kind,
    required this.enableTools,
  });
  final ResourceService<T> service;
  final String title, kind;
  final bool enableTools;
  @override
  State<_ManagementBody<T>> createState() => _ManagementBodyState<T>();
}

class _ManagementBodyState<T extends TransportRecord>
    extends State<_ManagementBody<T>> {
  late Future<List<T>> future;
  String query = '', filter = 'All';
  @override
  void initState() {
    super.initState();
    future = widget.service.list();
  }

  void reload() => setState(() {
    future = widget.service.list();
  });
  Future<void> form([T? item]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecordForm<T>(
          service: widget.service,
          kind: widget.kind,
          item: item,
        ),
      ),
    );
    if (saved == true && mounted) reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          onPressed: reload,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: form,
      tooltip: 'Add ${widget.kind}',
      child: const Icon(Icons.add),
    ),
    body: SafeArea(
      child: AsyncBody<List<T>>(
        future: future,
        retry: reload,
        builder: (items) {
          if (!widget.enableTools) return recordList(items);
          final statuses =
              items
                  .map((r) => r.status)
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();
          final activeFilter = statuses.contains(filter) ? filter : 'All';
          final visible = items
              .where(
                (r) =>
                    '${r.title} ${r.details.values.join(' ')}'
                        .toLowerCase()
                        .contains(query.toLowerCase()) &&
                    (activeFilter == 'All' || r.status == activeFilter),
              )
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Search ${widget.title.toLowerCase()}',
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() => query = v),
                      ),
                    ),
                    if (statuses.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          key: ValueKey('$filter-${statuses.join()}'),
                          initialValue: activeFilter,
                          decoration: const InputDecoration(
                            labelText: 'Filter status',
                          ),
                          items: ['All', ...statuses]
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => filter = v!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: recordList(visible)),
            ],
          );
        },
      ),
    ),
  );

  Widget recordList(List<T> items) => items.isEmpty
      ? Center(child: Text('No ${widget.title.toLowerCase()} found.'))
      : ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          itemCount: items.length,
          itemBuilder: (_, i) => RecordCard(
            record: items[i],
            onTap: () async {
              await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => RecordDetail<T>(
                    service: widget.service,
                    id: items[i].id,
                    kind: widget.kind,
                  ),
                ),
              );
              if (mounted) reload();
            },
          ),
        );
}

class RecordDetail<T extends TransportRecord> extends StatefulWidget {
  const RecordDetail({
    super.key,
    required this.service,
    required this.id,
    required this.kind,
  });
  final ResourceService<T> service;
  final int id;
  final String kind;
  @override
  State<RecordDetail<T>> createState() => _RecordDetailState<T>();
}

class _RecordDetailState<T extends TransportRecord>
    extends State<RecordDetail<T>> {
  Future<T>? future;
  bool changed = false;
  @override
  void initState() {
    super.initState();
    if (widget.service.api.session?.role == TransportRole.authority) {
      future = widget.service.get(widget.id);
    }
  }

  void reload() => setState(() {
    future = widget.service.get(widget.id);
  });
  @override
  Widget build(BuildContext context) => RoleGate(
    api: widget.service.api,
    role: TransportRole.authority,
    builder: (_) => Scaffold(
      appBar: AppBar(
        title: Text('${widget.kind} details'),
        leading: BackButton(onPressed: () => Navigator.pop(context, changed)),
      ),
      body: SafeArea(
        child: AsyncBody<T>(
          future: future!,
          retry: reload,
          builder: (item) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              RecordCard(record: item),
              FilledButton(
                onPressed: () async {
                  final saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => RecordForm<T>(
                        service: widget.service,
                        kind: widget.kind,
                        item: item,
                      ),
                    ),
                  );
                  if (saved == true && mounted) {
                    changed = true;
                    reload();
                  }
                },
                child: Text('Edit ${widget.kind}'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
