import 'package:flutter/material.dart';

import '../features/review/models.dart';
import 'corner_table.dart';
import 'delta_chart.dart';
import 'trace_chart.dart';
import 'track_map.dart';

/// Shared LapDistPct cursor across trace, delta, corner table, and map (KTD-6).
///
/// Layout mirrors Garage 61 analyze: track map on the left (fixed), telemetry
/// charts on the right (scrollable) so gaps can be traced on the map while
/// reading traces.
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
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '赛道地图',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: TrackMap(
                        refLap: refLap,
                        candLap: candLap,
                        highlightedPct: highlightedPct,
                        onHighlight: onHighlight,
                        expand: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '蓝 = 参考 · 橙 = 测试 · 标记 = 当前位置',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
