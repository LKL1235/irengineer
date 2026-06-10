import 'package:flutter/material.dart';

import '../domain/delta/engine.dart';

class CornerTable extends StatelessWidget {
  const CornerTable({
    super.key,
    required this.corners,
    required this.highlightedPct,
    this.onCornerTap,
  });

  final List<CornerResult> corners;
  final double highlightedPct;
  final void Function(int cornerIdx)? onCornerTap;

  @override
  Widget build(BuildContext context) {
    if (corners.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('未检测到弯道分段'),
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 32,
          columns: const [
            DataColumn(label: Text('弯')),
            DataColumn(label: Text('Δ (s)')),
            DataColumn(label: Text('刹车')),
            DataColumn(label: Text('顶点')),
            DataColumn(label: Text('出弯')),
            DataColumn(label: Text('信号')),
          ],
          rows: corners.map((c) {
            final selected = highlightedPct >= c.startPct &&
                highlightedPct <= c.endPct;
            final brake = _phaseDelta(c, DeltaPhase.brake);
            final apex = _phaseDelta(c, DeltaPhase.apex);
            final exit = _phaseDelta(c, DeltaPhase.exit);
            final signals = <String>[
              if (c.signals.earlyBrake) '早刹',
              if (c.signals.lateThrottle) '晚油',
              if (c.signals.wideApex) '宽弯',
            ].join(' ');
            return DataRow(
              selected: selected,
              onSelectChanged: onCornerTap == null
                  ? null
                  : (_) => onCornerTap!(c.cornerIdx),
              cells: [
                DataCell(Text('T${c.cornerIdx}')),
                DataCell(Text(c.deltaS.toStringAsFixed(3))),
                DataCell(Text(brake.toStringAsFixed(3))),
                DataCell(Text(apex.toStringAsFixed(3))),
                DataCell(Text(exit.toStringAsFixed(3))),
                DataCell(Text(signals)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  double _phaseDelta(CornerResult c, DeltaPhase phase) {
    for (final p in c.phases) {
      if (p.phase == phase) {
        return p.deltaS;
      }
    }
    return 0;
  }
}
