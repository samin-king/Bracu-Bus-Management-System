import 'package:flutter/material.dart';

import '../models/transport_record.dart';
import '../design/transport_theme.dart';

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
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xffeef3ff),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.directions_bus_outlined,
                  size: 19,
                  color: TransportColors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    record.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
            ],
          ),
          if (record.status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(record.status),
              ),
            ),
          const SizedBox(height: 19),
          const Divider(height: 1),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, bounds) {
              final columns = bounds.maxWidth > 850
                  ? 3
                  : bounds.maxWidth > 520
                  ? 2
                  : 1;
              return Wrap(
                spacing: 18,
                runSpacing: 10,
                children: [
                  for (final entry in record.details.entries)
                    SizedBox(
                      width: (bounds.maxWidth - (columns - 1) * 18) / columns,
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.65,
                          color: Color(0xff60718a),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (onTap != null)
            TextButton(onPressed: onTap, child: const Text('View details')),
          ...children,
        ],
      ),
    ),
  );
}
