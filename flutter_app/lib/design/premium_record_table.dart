import 'package:flutter/material.dart';
import '../models/transport_record.dart';
import 'transport_theme.dart';

class PremiumRecordTable<T extends TransportRecord> extends StatelessWidget {
  const PremiumRecordTable({
    super.key,
    required this.items,
    required this.kind,
    required this.open,
  });
  final List<T> items;
  final String kind;
  final ValueChanged<T> open;
  List<String> get columns => switch (kind) {
    'bus' => ['Registration number', 'Capacity', 'Status'],
    'route' => ['Origin', 'Destination', 'Stops'],
    'driver' => ['License number', 'Status'],
    _ => ['Bus', 'Departure', 'Driver', 'Status'],
  };
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Row(
                children: [
                  Text(
                    '${kind[0].toUpperCase()}${kind.substring(1)} directory',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffedf2ff),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${items.length} records',
                      style: const TextStyle(
                        fontSize: 9,
                        color: TransportColors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: (bounds.maxWidth - 34).clamp(0, double.infinity),
                ),
                child: DataTable(
                  horizontalMargin: 22,
                  columnSpacing: 24,
                  columns: [
                    DataColumn(label: Text(kind == 'trip' ? 'ROUTE' : 'NAME')),
                    for (final c in columns)
                      DataColumn(label: Text(c.toUpperCase())),
                    const DataColumn(label: Text('ACTION')),
                  ],
                  rows: [
                    for (final item in items)
                      DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xffedf2ff),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(
                                    kind == 'driver'
                                        ? Icons.badge_outlined
                                        : kind == 'route'
                                        ? Icons.alt_route_rounded
                                        : Icons.directions_bus_outlined,
                                    size: 16,
                                    color: TransportColors.blue,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 190,
                                  ),
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final c in columns)
                            DataCell(
                              c == 'Status'
                                  ? StatusBadge(item.status)
                                  : ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: c == 'Stops' ? 230 : 190,
                                      ),
                                      child: Text(
                                        item.details[c] ?? '—',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: c == 'Capacity'
                                              ? TransportColors.navy
                                              : TransportColors.muted,
                                        ),
                                      ),
                                    ),
                            ),
                          DataCell(
                            TextButton.icon(
                              onPressed: () => open(item),
                              icon: const Icon(
                                Icons.arrow_outward_rounded,
                                size: 13,
                              ),
                              label: const Text('View details'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
