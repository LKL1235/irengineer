import 'package:flutter/material.dart';

import '../features/review/models.dart';
import 'corner_table.dart';
import 'delta_chart.dart';
import 'trace_chart.dart';
import 'track_map.dart';

/// Shared LapDistPct cursor across trace, delta, corner table, and map (KTD-6).
class ReviewChartsPanel extends StatelessWidget {
  const ReviewChartsPanel({
    super.key,
    required this.analysis,
    required this.refLap,
    required this.candLap,
    required this.highlightedPct,
    required this.onHighlight,
    required this.onCornerTap,
  });

  final AnalysisBundle analysis;
  final ImportedLap? refLap;
  final ImportedLap? candLap;
  final double highlightedPct;
  final ValueChanged<double> onHighlight;
  final void Function(int cornerIndex) onCornerTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '总 Delta: ${analysis.report.totalDeltaS.toStringAsFixed(3)} s · '
          '参考 ${analysis.report.refLapTime.toStringAsFixed(3)} s · '
          '测试 ${analysis.report.candLapTime.toStringAsFixed(3)} s',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TraceChart(
          title: '速度 (km/h)',
          refGrid: analysis.refGrid,
          candGrid: analysis.candGrid,
          valueSelector: (g) => g.speed * 3.6,
          highlightedPct: highlightedPct,
          onHighlight: onHighlight,
        ),
        TraceChart(
          title: '刹车',
          refGrid: analysis.refGrid,
          candGrid: analysis.candGrid,
          valueSelector: (g) => g.brake,
          highlightedPct: highlightedPct,
          onHighlight: onHighlight,
        ),
        TraceChart(
          title: '油门',
          refGrid: analysis.refGrid,
          candGrid: analysis.candGrid,
          valueSelector: (g) => g.throttle,
          highlightedPct: highlightedPct,
          onHighlight: onHighlight,
        ),
        TraceChart(
          title: '转向',
          refGrid: analysis.refGrid,
          candGrid: analysis.candGrid,
          valueSelector: (g) => g.steer,
          highlightedPct: highlightedPct,
          onHighlight: onHighlight,
        ),
        DeltaChart(
          refGrid: analysis.refGrid,
          deltaCurve: analysis.deltaCurve,
          highlightedPct: highlightedPct,
          onHighlight: onHighlight,
        ),
        CornerTable(
          corners: analysis.report.corners,
          highlightedPct: highlightedPct,
          onCornerTap: onCornerTap,
        ),
        const SizedBox(height: 8),
        TrackMap(
          refLap: refLap,
          candLap: candLap,
          highlightedPct: highlightedPct,
          onHighlight: onHighlight,
        ),
      ],
    );
  }
}
