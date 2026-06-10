import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../domain/delta/engine.dart';

class DeltaChart extends StatelessWidget {
  const DeltaChart({
    super.key,
    required this.refGrid,
    required this.deltaCurve,
    required this.highlightedPct,
    this.onHighlight,
  });

  final List<GridSample> refGrid;
  final List<double> deltaCurve;
  final double highlightedPct;
  final void Function(double pct)? onHighlight;

  @override
  Widget build(BuildContext context) {
    if (refGrid.isEmpty || deltaCurve.isEmpty) {
      return const SizedBox.shrink();
    }
    final spots = <FlSpot>[];
    for (var i = 0; i < refGrid.length && i < deltaCurve.length; i++) {
      spots.add(FlSpot(refGrid[i].pct * 100, deltaCurve[i]));
    }
    final ys = spots.map((s) => s.y);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) * 0.05 + 0.01;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('累计 Delta (s)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            SizedBox(
              height: 140,
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
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text(
                          v.toStringAsFixed(2),
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
                      onHighlight!(response!.lineBarSpots!.first.x / 100);
                    },
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 0,
                        color: Colors.grey,
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ],
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
                      spots: spots,
                      isCurved: false,
                      color: Colors.green.shade700,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
