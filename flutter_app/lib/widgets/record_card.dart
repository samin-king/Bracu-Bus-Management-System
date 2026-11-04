import 'package:flutter/material.dart';

import '../models/transport_record.dart';

class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.record,
    this.onTap,
    this.children = const [],
  });
  final TransportRecord record;
  final VoidCallback? onTap;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(record.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final entry in record.details.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${entry.key}: ${entry.value}'),
                ),
              if (onTap != null)
                TextButton(onPressed: onTap, child: const Text('View details')),
              ...children,
            ],
          ),
        ),
      );
}
