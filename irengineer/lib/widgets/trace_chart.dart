import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../domain/delta/engine.dart';

typedef PctCallback = void Function(double pct);

class TraceChart extends StatelessWidget {
  const TraceChart({
    super.key,
    required this.title,
    required this.refGrid,
    required this.candGrid,
    required this.valueSelector,
    required this.highlightedPct,
    this.onHighlight,
    this.unit = '',
  });

  final String title;
  final List<GridSample> refGrid;
  final List<GridSample> candGrid;
  final double Function(GridSample) valueSelector;
  final double highlightedPct;
  final PctCallback? onHighlight;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (refGrid.isEmpty) {
      return const SizedBox.shrink();
    }
    final refSpots = refGrid
        .map((g) => FlSpot(g.pct * 100, valueSelector(g)))
        .toList();
    final candSpots = candGrid
        .map((g) => FlSpot(g.pct * 100, valueSelector(g)))
        .toList();
    final allY = [...refSpots, ...candSpots].map((s) => s.y);
    final minY = allY.reduce((a, b) => a < b ? a : b);
    final maxY = allY.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.05 + 0.01;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 100,
                  minY: minY - pad,
                  maxY: maxY + pad,
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 25,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toInt()}%',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, _) => Text(
                          v.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                  ),
                  borderData: FlBorderData(show: true),
                  lineTouchData: LineTouchData(
                    touchCallback: (event, response) {
                      if (onHighlight == null || response?.lineBarSpots == null) {
                        return;
                      }
                      final spot = response!.lineBarSpots!.first;
                      onHighlight!(spot.x / 100);
                    },
                  ),
                  extraLinesData: ExtraLinesData(
                    verticalLines: [
                      VerticalLine(
                        x: highlightedPct * 100,
                        color: Colors.amber.withValues(alpha: 0.8),
                        strokeWidth: 1.5,
                      ),
                    ],
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: refSpots,
                      isCurved: false,
                      color: Colors.blue,
                      barWidth: 1.5,
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: candSpots,
                      isCurved: false,
                      color: Colors.orange,
                      barWidth: 1.5,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            if (unit.isNotEmpty)
              Text(unit, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
